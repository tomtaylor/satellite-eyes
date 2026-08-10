import Cocoa
import CoreLocation
import Network
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SatelliteEyes", category: "MapManager")
private let baseTileSize: CGFloat = 256

// `CLLocationManagerDelegate` isn't main actor-isolated, but the location
// manager is created here on the main actor and so calls back on it. The
// `@preconcurrency` conformance keeps the delegate methods main actor-isolated,
// with a runtime check on entry.
@MainActor
final class MapManager: NSObject, @preconcurrency CLLocationManagerDelegate {

    // MARK: - Notification names

    nonisolated static let startedLoadNotification = NSNotification.Name("TTMapManagerStartedLoad")
    nonisolated static let failedLoadNotification = NSNotification.Name("TTMapManagerFailedLoad")
    nonisolated static let finishedLoadNotification = NSNotification.Name("TTMapManagerFinishedLoad")
    nonisolated static let locationUpdatedNotification = NSNotification.Name("TTMapManagerLocationUpdated")
    nonisolated static let locationLostNotification = NSNotification.Name("TTMapManagerLocationLost")
    nonisolated static let locationPermissionDeniedNotification = NSNotification.Name("TTMapManagerLocationPermissionDenied")
    nonisolated static let randomLocationSelectedNotification = NSNotification.Name("TTMapManagerRandomLocationSelected")

    // MARK: - Private state

    private let locationManager = CLLocationManager()
    private var lastSeenLocation: CLLocation?
    /// Map updates are chained onto this task so they run one at a time, in the
    /// order they were requested.
    private var updateTask: Task<Void, Never>?
    private let pathMonitor = NWPathMonitor()
    private var networkSatisfied = false
    private var hasStarted = false
    private var currentRandomLocation: LocationStore.NamedLocation?
    /// The category `currentRandomLocation` was picked under, so a category
    /// change that has already been handled can be recognised and skipped.
    private var currentRandomLocationCategory: String?
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

        // Network monitoring. The monitor is started on the main queue, so the
        // handler is always already on the main actor.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated {
                self?.networkPathChanged(satisfied: path.status == .satisfied)
            }
        }
        pathMonitor.start(queue: .main)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        UserDefaults.standard.addObserver(self, forKeyPath: "selectedMapTypeId", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "zoomLevel", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "selectedImageEffectId", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "useCurrentLocation", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "randomLocationCategory", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "rotationIntervalSeconds", options: .new, context: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(receiveWakeNote),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    // Isolated so it can tear down the main actor-isolated state it set up.
    isolated deinit {
        pathMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedMapTypeId")
        UserDefaults.standard.removeObserver(self, forKeyPath: "zoomLevel")
        UserDefaults.standard.removeObserver(self, forKeyPath: "selectedImageEffectId")
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
            locationManager.startUpdatingLocation()
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
        let previousUpdate = updateTask
        updateTask = Task { [weak self] in
            await previousUpdate?.value
            await self?.performUpdate(to: coordinate, force: force)
        }
    }

    /// Renders and applies the wallpaper for every screen, one at a time. Runs
    /// on the main actor; only the tile fetching and compositing inside
    /// `MapImage.fetchTiles` hops off it.
    private func performUpdate(to coordinate: CLLocationCoordinate2D, force: Bool) async {
        for screen in NSScreen.screens {
            guard let mapImage = makeMapImage(for: screen, coordinate: coordinate) else { continue }

            NotificationCenter.default.post(name: Self.startedLoadNotification, object: nil)

            do {
                let filePath = try await mapImage.fetchTiles(skipCache: force)
                NotificationCenter.default.post(name: Self.finishedLoadNotification, object: nil)
                await setDesktopImage(filePath, for: screen, force: force)
            } catch {
                NotificationCenter.default.post(name: Self.failedLoadNotification, object: nil)
                log.error("Error fetching image: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makeMapImage(for screen: NSScreen, coordinate: CLLocationCoordinate2D) -> MapImage? {
        // The update loop suspends between screens while tiles are fetched, so
        // a display reconfiguration can land mid-update and briefly leave no
        // main screen. Skip this render; screensChanged queues a fresh one.
        guard let mainFrame = NSScreen.main?.frame else { return nil }

        let effectiveZoom: UInt16
        let tileRect: CGRect
        let scale: Float
        let displayScale: Float?

        if shouldUpscaleRetina(for: screen) {
            effectiveZoom = zoomLevel + 1
            let baseRect = self.tileRect(for: screen, coordinate: coordinate, zoomLevel: zoomLevel, mainFrame: mainFrame)
            tileRect = CGRect(x: baseRect.origin.x * 2,
                              y: baseRect.origin.y * 2,
                              width: baseRect.size.width * 2,
                              height: baseRect.size.height * 2)
            scale = 1
            displayScale = Float(screen.backingScaleFactor)
        } else {
            effectiveZoom = zoomLevel
            tileRect = self.tileRect(for: screen, coordinate: coordinate, zoomLevel: zoomLevel, mainFrame: mainFrame)
            scale = tileScale(for: screen)
            displayScale = nil
        }

        return MapImage(
            tileRect: tileRect, tileScale: scale, zoomLevel: effectiveZoom,
            source: source(for: screen), effect: selectedImageEffect, logoData: logoData,
            displayScale: displayScale)
    }

    private func setDesktopImage(_ filePath: URL, for screen: NSScreen, force: Bool) async {
        // A forced refresh onto the same file needs a detour via another image,
        // otherwise the system ignores it as an unchanged wallpaper.
        if force, NSWorkspace.shared.desktopImageURL(for: screen) == filePath,
           let tempImage = Bundle.main.urlForImageResource("loading") {
            try? NSWorkspace.shared.setDesktopImageURL(tempImage, for: screen, options: [:])
            try? await Task.sleep(for: .seconds(1))
        }

        try? NSWorkspace.shared.setDesktopImageURL(filePath, for: screen, options: [:])
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

    /// KVO callbacks arrive on whichever thread changed the preference, so hop
    /// to the main actor before touching any state.
    nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                           change: [NSKeyValueChangeKey: Any]?,
                                           context: UnsafeMutableRawPointer?) {
        Task { @MainActor [weak self] in
            self?.preferenceChanged(keyPath)
        }
    }

    private func preferenceChanged(_ keyPath: String?) {
        switch keyPath {
        case "useCurrentLocation":
            handleLocationModeChange()
        case "randomLocationCategory":
            // Switching location source writes useCurrentLocation and
            // randomLocationCategory together, and the useCurrentLocation
            // handler runs first and picks under the new category. Only
            // re-pick if the category differs from the one the current
            // location was picked under, so one change means one update.
            if !useCurrentLocation && randomLocationCategory != currentRandomLocationCategory {
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

    private func networkPathChanged(satisfied: Bool) {
        let wasSatisfied = networkSatisfied
        networkSatisfied = satisfied

        if networkSatisfied && !wasSatisfied {
            updateMap()
        } else if !networkSatisfied && wasSatisfied {
            restartMap()
        }
    }

    @objc private func screensChanged(_ notification: Notification) { updateMap() }
    @objc private func spaceChanged(_ notification: Notification) { updateMap() }
    @objc private func receiveWakeNote(_ notification: Notification) { restartMap() }

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
            currentRandomLocationCategory = nil
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
        let category = randomLocationCategory
        guard let namedLocation = LocationStore.randomLocation(forCategory: category) else { return }
        currentRandomLocation = namedLocation
        currentRandomLocationCategory = category

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
        // Scheduled from the main actor, so the timer fires on the main run loop.
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pickRandomLocationAndUpdate()
            }
        }
        rotationTimer?.tolerance = 60
    }

    private func tileRect(for screen: NSScreen, coordinate: CLLocationCoordinate2D,
                          zoomLevel: UInt16, mainFrame: CGRect) -> CGRect {
        let centerTile = MapTile.coordinateToPoint(coordinate, zoomLevel: zoomLevel)
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

    private var selectedImageEffect: ImageEffect {
        let effects = UserDefaults.standard.array(forKey: "imageEffectTypes") as? [NSDictionary] ?? []
        let selectedId = UserDefaults.standard.string(forKey: "selectedImageEffectId")
        let selected = effects.first { ($0["id"] as? String) == selectedId } ?? effects.first
        guard let selected else { return ImageEffect() }
        return ImageEffect(dictionary: selected)
    }

    private var zoomLevel: UInt16 {
        let maxZoom = (selectedMapType["maxZoom"] as? NSNumber)?.intValue
        let minZoom = (selectedMapType["minZoom"] as? NSNumber)?.intValue
        var desired = UserDefaults.standard.integer(forKey: "zoomLevel")

        if let max = maxZoom, desired > max { desired = max }
        if let min = minZoom, desired < min { desired = min }

        return UInt16(desired)
    }

    /// The map style's logo as image data, so the renderer can decode it off the
    /// main actor.
    private var logoData: Data? {
        guard let name = selectedMapType["logoImage"] as? String else { return nil }
        return NSImage(named: name)?.tiffRepresentation
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
