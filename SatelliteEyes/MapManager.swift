import Cocoa
import CoreLocation
import Network
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SatelliteEyes", category: "MapManager")
private let baseTileSize: CGFloat = 256

class MapManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Notification names

    static let startedLoadNotification = NSNotification.Name("TTMapManagerStartedLoad")
    static let failedLoadNotification = NSNotification.Name("TTMapManagerFailedLoad")
    static let finishedLoadNotification = NSNotification.Name("TTMapManagerFinishedLoad")
    static let locationUpdatedNotification = NSNotification.Name("TTMapManagerLocationUpdated")
    static let locationLostNotification = NSNotification.Name("TTMapManagerLocationLost")
    static let locationPermissionDeniedNotification = NSNotification.Name("TTMapManagerLocationPermissionDenied")
    static let randomLocationSelectedNotification = NSNotification.Name("TTMapManagerRandomLocationSelected")

    // MARK: - Private state

    private let locationManager = CLLocationManager()
    private var lastSeenLocation: CLLocation?
    private let updateQueue = DispatchQueue(label: "uk.co.tomtaylor.satelliteeyes.mapupdate")
    private let pathMonitor = NWPathMonitor()
    private var networkSatisfied = false
    private var hasStarted = false
    private var currentRandomLocation: LocationStore.NamedLocation?
    private var rotationTimer: Timer?

    private var useCurrentLocation: Bool {
        UserDefaults.standard.bool(forKey: "useCurrentLocation")
    }

    private var randomLocationCategory: String {
        UserDefaults.standard.string(forKey: "randomLocationCategory") ?? ""
    }

    private var rotationIntervalSeconds: TimeInterval {
        max(3600, TimeInterval(UserDefaults.standard.integer(forKey: "rotationIntervalSeconds")))
    }

    // MARK: - Init

    override init() {
        super.init()

        locationManager.distanceFilter = 300
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self

        // Network monitoring
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasSatisfied = networkSatisfied
            networkSatisfied = path.status == .satisfied

            if networkSatisfied && !wasSatisfied {
                updateMap()
            } else if !networkSatisfied && wasSatisfied {
                restartMap()
            }
        }
        pathMonitor.start(queue: .main)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        UserDefaults.standard.addObserver(self, forKeyPath: "selectedMapTypeId", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "zoomLevel", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "selectedImageEffectId", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "selectedImageEffectIdLight", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "selectedImageEffectIdDark", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "useCurrentLocation", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "randomLocationCategory", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "rotationIntervalSeconds", options: .new, context: nil)

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(receiveWakeNote),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    deinit {
        pathMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedMapTypeId")
        UserDefaults.standard.removeObserver(self, forKeyPath: "zoomLevel")
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedImageEffectId")
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedImageEffectIdLight")
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedImageEffectIdDark")
        UserDefaults.standard.removeObserver(self, forKeyPath: "useCurrentLocation")
        UserDefaults.standard.removeObserver(self, forKeyPath: "randomLocationCategory")
        UserDefaults.standard.removeObserver(self, forKeyPath: "rotationIntervalSeconds")
        rotationTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Public API

    func start() {
        hasStarted = true

        if useCurrentLocation {
            guard CLLocationManager.locationServicesEnabled() else {
                NotificationCenter.default.post(name: Self.locationPermissionDeniedNotification, object: nil)
                return
            }

            // Request authorization if needed, otherwise start updating
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestAlwaysAuthorization()
            } else if status == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
        } else {
            pickRandomLocationAndUpdate()
            scheduleRotationTimer()
        }
    }

    func updateMap() {
        guard let location = lastSeenLocation else { return }
        updateMap(to: location.coordinate, force: false)
    }

    func forceUpdateMap() {
        if useCurrentLocation {
            guard let location = lastSeenLocation else { return }
            updateMap(to: location.coordinate, force: true)
        } else {
            pickRandomLocationAndUpdate(force: true)
            scheduleRotationTimer()
        }
    }

    func updateMap(to coordinate: CLLocationCoordinate2D, force: Bool) {
        for screen in NSScreen.screens {
            updateQueue.async { [self] in
                NotificationCenter.default.post(name: Self.startedLoadNotification, object: nil)

                let effectiveZoom: UInt16
                let tileRect: CGRect
                let source: String
                let scale: Float
                let displayScale: Float?

                if shouldUpscaleRetina(for: screen) {
                    effectiveZoom = zoomLevel + 1
                    let baseRect = self.tileRect(for: screen, coordinate: coordinate, zoomLevel: zoomLevel)
                    tileRect = CGRect(x: baseRect.origin.x * 2,
                                      y: baseRect.origin.y * 2,
                                      width: baseRect.size.width * 2,
                                      height: baseRect.size.height * 2)
                    source = self.source(for: screen)
                    scale = 1
                    displayScale = Float(screen.backingScaleFactor)
                } else {
                    effectiveZoom = zoomLevel
                    tileRect = self.tileRect(for: screen, coordinate: coordinate, zoomLevel: zoomLevel)
                    source = self.source(for: screen)
                    scale = self.tileScale(for: screen)
                    displayScale = nil
                }

                let mapImage = MapImage(
                    tileRect: tileRect, tileScale: scale, zoomLevel: effectiveZoom,
                    source: source, effect: selectedImageEffect, logo: logoImage,
                    displayScale: displayScale)

                mapImage.fetchTilesWithSuccess({ filePath in
                    NotificationCenter.default.post(name: Self.finishedLoadNotification, object: nil)

                    let currentImageURL = NSWorkspace.shared.desktopImageURL(for: screen)

                    if force && currentImageURL == filePath {
                        let tempImage = Bundle.main.urlForImageResource("loading")!
                        try? NSWorkspace.shared.setDesktopImageURL(tempImage, for: screen, options: [:])

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            try? NSWorkspace.shared.setDesktopImageURL(filePath, for: screen, options: [:])
                        }
                    } else {
                        try? NSWorkspace.shared.setDesktopImageURL(filePath, for: screen, options: [:])
                    }

                }, failure: { error in
                    NotificationCenter.default.post(name: Self.failedLoadNotification, object: nil)
                    log.error("Error fetching image: \(error.localizedDescription, privacy: .public)")
                }, skipCache: force)
            }
        }
    }

    func cleanCache() {
        let cachePath = FileManager.default.privateDataPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cachePath) else { return }

        // Find current wallpaper filenames to protect
        let safeFiles = NSScreen.screens.compactMap {
            NSWorkspace.shared.desktopImageURL(for: $0)?.lastPathComponent
        }

        // Find map files not currently on desktop
        let filesToRemove = files.filter { $0.hasPrefix("map") && !safeFiles.contains($0) }

        // Build (path, modDate) pairs
        var filesAndDates: [(path: String, date: Date)] = []
        for file in filesToRemove {
            let filePath = (cachePath as NSString).appendingPathComponent(file)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                  let modDate = attrs[.modificationDate] as? Date else { continue }
            filesAndDates.append((filePath, modDate))
        }

        // Sort by most recent first, keep 20, delete rest
        filesAndDates.sort { $0.date > $1.date }
        for entry in filesAndDates.dropFirst(20) {
            try? FileManager.default.removeItem(atPath: entry.path)
        }
    }

    var browserURL: URL? {
        guard let location = lastSeenLocation,
              let template = selectedMapType["browserURL"] as? String else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8

        let lat = formatter.string(from: NSNumber(value: location.coordinate.latitude)) ?? ""
        let lon = formatter.string(from: NSNumber(value: location.coordinate.longitude)) ?? ""
        let zoom = "\(zoomLevel)"

        let urlString = template
            .replacingOccurrences(of: "{latitude}", with: lat)
            .replacingOccurrences(of: "{longitude}", with: lon)
            .replacingOccurrences(of: "{zoom}", with: zoom)

        return URL(string: urlString)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last,
              abs(newLocation.timestamp.timeIntervalSinceNow) < 120 else { return }

        NotificationCenter.default.post(name: Self.locationUpdatedNotification, object: newLocation)
        lastSeenLocation = newLocation
        updateMap(to: newLocation.coordinate, force: false)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard useCurrentLocation else { return }
        if (error as NSError).code == CLError.denied.rawValue {
            // If status is still undetermined, the system prompt is showing — don't treat as denied yet
            guard locationManager.authorizationStatus != .notDetermined else { return }
            locationManager.stopUpdatingLocation()
            NotificationCenter.default.post(name: Self.locationPermissionDeniedNotification, object: nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard hasStarted, useCurrentLocation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            NotificationCenter.default.post(name: Self.locationPermissionDeniedNotification, object: nil)
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "useCurrentLocation":
            handleLocationModeChange()
        case "randomLocationCategory":
            if !useCurrentLocation {
                pickRandomLocationAndUpdate()
                scheduleRotationTimer()
            }
        case "rotationIntervalSeconds":
            if !useCurrentLocation {
                scheduleRotationTimer()
            }
        default:
            updateMap()
        }
    }

    // MARK: - Private

    @objc private func screensChanged(_ notification: Notification) { updateMap() }
    @objc private func spaceChanged(_ notification: Notification) { updateMap() }
    @objc private func receiveWakeNote(_ notification: Notification) { restartMap() }
    @objc private func appearanceChanged(_ notification: Notification) { updateMap() }

    private func restartMap() {
        if useCurrentLocation {
            locationManager.stopUpdatingLocation()
            lastSeenLocation = nil
            NotificationCenter.default.post(name: Self.locationLostNotification, object: nil)
            locationManager.startUpdatingLocation()
        } else {
            // In random mode, just re-render the current location (don't pick a new one on wake)
            updateMap()
        }
    }

    private func handleLocationModeChange() {
        guard hasStarted else { return }

        if useCurrentLocation {
            // Switching to GPS mode
            rotationTimer?.invalidate()
            rotationTimer = nil
            currentRandomLocation = nil
            lastSeenLocation = nil
            NotificationCenter.default.post(name: Self.locationLostNotification, object: nil)

            guard CLLocationManager.locationServicesEnabled() else {
                NotificationCenter.default.post(name: Self.locationPermissionDeniedNotification, object: nil)
                return
            }
            locationManager.startUpdatingLocation()
        } else {
            // Switching to random mode
            locationManager.stopUpdatingLocation()
            pickRandomLocationAndUpdate()
            scheduleRotationTimer()
        }
    }

    private func pickRandomLocationAndUpdate(force: Bool = false) {
        guard let namedLocation = LocationStore.randomLocation(forCategory: randomLocationCategory) else { return }
        currentRandomLocation = namedLocation

        let location = CLLocation(latitude: namedLocation.coordinate.latitude,
                                  longitude: namedLocation.coordinate.longitude)
        lastSeenLocation = location

        NotificationCenter.default.post(name: Self.randomLocationSelectedNotification, object: namedLocation.name)
        NotificationCenter.default.post(name: Self.locationUpdatedNotification, object: location)
        updateMap(to: namedLocation.coordinate, force: force)
    }

    private func scheduleRotationTimer() {
        rotationTimer?.invalidate()
        let interval = rotationIntervalSeconds
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pickRandomLocationAndUpdate()
        }
        rotationTimer?.tolerance = 60
    }

    private func tileRect(for screen: NSScreen, coordinate: CLLocationCoordinate2D,
                          zoomLevel: UInt16) -> CGRect {
        let centerTile = MapTile.coordinateToPoint(coordinate, zoomLevel: zoomLevel)
        let mainFrame = NSScreen.main!.frame
        let targetFrame = screen.frame

        let mainTileH = mainFrame.height / baseTileSize
        let mainTileW = mainFrame.width / baseTileSize
        let mainTileOriginX = centerTile.x - mainTileW / 2
        let mainTileOriginY = centerTile.y + mainTileH / 2

        let targetTileH = targetFrame.height / baseTileSize
        let targetTileW = targetFrame.width / baseTileSize
        let targetTileOriginX = mainTileOriginX + targetFrame.origin.x / baseTileSize
        let targetTileOriginY = mainTileOriginY - targetFrame.origin.y / baseTileSize

        return CGRect(x: targetTileOriginX, y: targetTileOriginY,
                      width: targetTileW, height: targetTileH)
    }

    private var selectedMapType: NSDictionary {
        let builtIn = MapStyle.builtInMapTypes() as [NSDictionary]
        let custom = (UserDefaults.standard.array(forKey: "customMapTypes") as? [NSDictionary]) ?? []
        let allMapTypes = builtIn + custom
        let selectedId = UserDefaults.standard.string(forKey: "selectedMapTypeId")
        return allMapTypes.first { ($0["id"] as? String) == selectedId } ?? builtIn.first ?? [:]
    }

    private var selectedImageEffect: NSDictionary {
        let effects = UserDefaults.standard.array(forKey: "imageEffectTypes") as? [NSDictionary] ?? []

        // Determine which effect ID to use based on system appearance
        let selectedId: String?
        let appearanceName = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        if appearanceName == .darkAqua {
            selectedId = UserDefaults.standard.string(forKey: "selectedImageEffectIdDark")
        } else {
            selectedId = UserDefaults.standard.string(forKey: "selectedImageEffectIdLight")
        }

        return effects.first { ($0["id"] as? String) == selectedId } ?? effects.first ?? [:]
    }

    private var zoomLevel: UInt16 {
        let maxZoom = (selectedMapType["maxZoom"] as? NSNumber)?.intValue
        let minZoom = (selectedMapType["minZoom"] as? NSNumber)?.intValue
        var desired = UserDefaults.standard.integer(forKey: "zoomLevel")

        if let max = maxZoom, desired > max { desired = max }
        if let min = minZoom, desired < min { desired = min }

        return UInt16(desired)
    }

    private var logoImage: NSImage? {
        guard let name = selectedMapType["logoImage"] as? String else { return nil }
        return NSImage(named: name)
    }

    private func screenIsRetina(_ screen: NSScreen) -> Bool {
        screen.backingScaleFactor > 1
    }

    private func source(for screen: NSScreen) -> String {
        if let source2x = selectedMapType["source2x"] as? String, screenIsRetina(screen) {
            return source2x
        }
        return selectedMapType["source"] as? String ?? ""
    }

    private func tileScale(for screen: NSScreen) -> Float {
        if selectedMapType["source2x"] != nil && screenIsRetina(screen) {
            return 2
        }
        return 1
    }

    private func shouldUpscaleRetina(for screen: NSScreen) -> Bool {
        guard selectedMapType["upscaleRetina"] as? Bool == true,
              selectedMapType["source2x"] == nil,
              screenIsRetina(screen) else { return false }
        let maxZoom = (selectedMapType["maxZoom"] as? NSNumber)?.intValue ?? Int(UInt16.max)
        return Int(zoomLevel) + 1 <= maxZoom
    }
}
