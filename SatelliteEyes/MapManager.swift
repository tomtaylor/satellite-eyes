import Cocoa
import CoreLocation
import Network
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SatelliteEyes", category: "MapManager")
private let baseTileSize: CGFloat = 256

@objc(TTMapManager)
class MapManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Notification names

    @objc static let startedLoadNotification = NSNotification.Name("TTMapManagerStartedLoad")
    @objc static let failedLoadNotification = NSNotification.Name("TTMapManagerFailedLoad")
    @objc static let finishedLoadNotification = NSNotification.Name("TTMapManagerFinishedLoad")
    @objc static let locationUpdatedNotification = NSNotification.Name("TTMapManagerLocationUpdated")
    @objc static let locationLostNotification = NSNotification.Name("TTMapManagerLocationLost")
    @objc static let locationPermissionDeniedNotification = NSNotification.Name("TTMapManagerLocationPermissionDenied")

    // MARK: - Private state

    private let locationManager = CLLocationManager()
    private var lastSeenLocation: CLLocation?
    private let updateQueue = DispatchQueue(label: "uk.co.tomtaylor.satelliteeyes.mapupdate")
    private let pathMonitor = NWPathMonitor()
    private var networkSatisfied = false

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
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedMapTypeId")
        UserDefaults.standard.removeObserver(self, forKeyPath: "zoomLevel")
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedImageEffectId")
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Public API

    @objc func start() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        } else {
            NotificationCenter.default.post(name: Self.locationPermissionDeniedNotification, object: nil)
        }
    }

    @objc func updateMap() {
        guard let location = lastSeenLocation else { return }
        updateMap(to: location.coordinate, force: false)
    }

    @objc func forceUpdateMap() {
        guard let location = lastSeenLocation else { return }
        updateMap(to: location.coordinate, force: true)
    }

    @objc(updateMapToCoordinate:force:)
    func updateMap(to coordinate: CLLocationCoordinate2D, force: Bool) {
        for screen in NSScreen.screens {
            updateQueue.async { [self] in
                NotificationCenter.default.post(name: Self.startedLoadNotification, object: nil)

                let tileRect = self.tileRect(for: screen, coordinate: coordinate, zoomLevel: zoomLevel)
                let source = self.source(for: screen)
                let scale = self.tileScale(for: screen)

                let mapImage = MapImage(
                    tileRect: tileRect, tileScale: scale, zoomLevel: zoomLevel,
                    source: source, effect: selectedImageEffect, logo: logoImage)

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

    @objc func cleanCache() {
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

    @objc var browserURL: URL? {
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
        if (error as NSError).code == CLError.denied.rawValue {
            locationManager.stopUpdatingLocation()
            NotificationCenter.default.post(name: Self.locationPermissionDeniedNotification, object: nil)
        }
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        updateMap()
    }

    // MARK: - Private

    @objc private func screensChanged(_ notification: Notification) { updateMap() }
    @objc private func spaceChanged(_ notification: Notification) { updateMap() }
    @objc private func receiveWakeNote(_ notification: Notification) { restartMap() }

    private func restartMap() {
        locationManager.stopUpdatingLocation()
        lastSeenLocation = nil
        NotificationCenter.default.post(name: Self.locationLostNotification, object: nil)
        locationManager.startUpdatingLocation()
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
        let mapTypes = UserDefaults.standard.array(forKey: "mapTypes") as? [NSDictionary] ?? []
        let selectedId = UserDefaults.standard.string(forKey: "selectedMapTypeId")
        return mapTypes.first { ($0["id"] as? String) == selectedId } ?? mapTypes.first ?? [:]
    }

    private var selectedImageEffect: NSDictionary {
        let effects = UserDefaults.standard.array(forKey: "imageEffectTypes") as? [NSDictionary] ?? []
        let selectedId = UserDefaults.standard.string(forKey: "selectedImageEffectId")
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
}
