import Cocoa
import Sparkle

@main
struct SatelliteEyesApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        setupMainMenu()
        app.run()
    }

    private static func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Satellite Eyes",
                                   action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences\u{2026}",
                                   action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Satellite Eyes",
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        // An Edit menu is required for keyboard shortcuts (Cmd+C/V/X/A/Z) to
        // work in the text fields in the Manage Custom Map Styles window. AppKit
        // routes these keys through the menu's key equivalents and responder chain.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        NSApplication.shared.mainMenu = mainMenu
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private var mapManager: MapManager!
    private var statusItemController: StatusItemController!
    private var preferencesWindowController: PreferencesWindowController!
    private var aboutWindowController: AboutWindowController!
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

        preferencesWindowController = PreferencesWindowController()
        aboutWindowController = AboutWindowController()

        registerDefaults()

        URLCache.shared.diskCapacity = 100 * 1024 * 1024

        statusItemController = StatusItemController()
        mapManager = MapManager()

        if UserDefaults.standard.bool(forKey: "cleanCache") {
            mapManager.cleanCache()
        }

        NotificationCenter.default.addObserver(
            forName: MapManager.locationPermissionDeniedNotification,
            object: nil, queue: nil) { [weak self] _ in
                guard UserDefaults.standard.bool(forKey: "useCurrentLocation") else { return }
                self?.handleLocationPermissionDenied()
            }

        doFirstRun()
        mapManager.start()
    }

    // MARK: - Actions (used by StatusItemController menu)

    @objc func menuActionExit(_ sender: Any?) {
        NSApplication.shared.terminate(self)
    }

    @objc func showPreferences(_ sender: Any?) {
        activateApp()
        preferencesWindowController.showWindow(self)
        preferencesWindowController.window?.orderFrontRegardless()
        preferencesWindowController.window?.makeFirstResponder(nil)
    }

    @objc func showAbout(_ sender: Any?) {
        activateApp()
        aboutWindowController.showWindow(self)
        aboutWindowController.window?.orderFrontRegardless()
        aboutWindowController.window?.makeFirstResponder(nil)
    }

    @objc func forceMapUpdate(_ sender: Any?) {
        mapManager.forceUpdateMap()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    @objc func openMapInBrowser(_ sender: Any?) {
        if let url = mapManager.browserURL {
            NSWorkspace.shared.open(url)
        }
    }

    var visibleMapBrowserURL: URL? {
        mapManager.browserURL
    }

    // MARK: - Private

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApplication.shared.activate()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func registerDefaults() {
        guard let path = Bundle.main.path(forResource: "Defaults", ofType: "plist"),
              let defaults = NSDictionary(contentsOfFile: path) as? [String: Any] else { return }
        UserDefaults.standard.register(defaults: defaults)

        migrateCustomMapTypes()
    }

    /// Migrate any user-added map types from the old `mapTypes` key to `customMapTypes`.
    private func migrateCustomMapTypes() {
        // Only migrate if customMapTypes hasn't been created yet and mapTypes was explicitly set
        guard UserDefaults.standard.array(forKey: "customMapTypes") == nil,
              let savedMapTypes = UserDefaults.standard.array(forKey: "mapTypes") as? [[String: Any]] else { return }

        let builtInIds = Set(MapStyle.builtInMapTypes().compactMap { $0["id"] as? String })
        let customEntries = savedMapTypes.filter { entry in
            guard let id = entry["id"] as? String else { return true }
            return !builtInIds.contains(id)
        }

        if !customEntries.isEmpty {
            UserDefaults.standard.set(customEntries, forKey: "customMapTypes")
        }

        // Remove the explicit mapTypes key so registration defaults take over
        UserDefaults.standard.removeObject(forKey: "mapTypes")
    }

    private func doFirstRun() {
        let key = "doneFirstRun"
        if !UserDefaults.standard.bool(forKey: key) {
            doLocationChoiceAlert()
            doStartupAlert()
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    private func doLocationChoiceAlert() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Satellite Eyes"
        alert.informativeText = """
            Satellite Eyes sets your desktop wallpaper to a map of your surroundings. \
            It runs in the status bar at the top of your screen.

            Would you like to use your current location, or explore random \
            interesting places around the world?
            """
        alert.addButton(withTitle: "Use My Location")
        alert.addButton(withTitle: "Random Places")

        if alert.runModal() != .alertFirstButtonReturn {
            UserDefaults.standard.set(false, forKey: "useCurrentLocation")
        }
    }

    private func doStartupAlert() {
        let alert = NSAlert()
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        alert.messageText = "Run Satellite Eyes at Startup?"
        alert.informativeText = "Satellite Eyes works best when it's run in the background all the time. Do you want it to run automatically at startup?"

        if alert.runModal() == .alertFirstButtonReturn {
            LoginItemManager.setLaunchAtLogin(true)
        } else {
            LoginItemManager.setLaunchAtLogin(false)
        }
    }

    private func handleLocationPermissionDenied() {
        UserDefaults.standard.set(false, forKey: "useCurrentLocation")

        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = "Location Access Not Available"
        alert.informativeText = """
            Satellite Eyes doesn't have permission to access your location.

            The app will show random interesting places instead. You can enable \
            Location Services in System Settings > Privacy & Security > Location Services, \
            then switch back to "Your Location" in Preferences.
            """
        alert.runModal()
    }
}

// MARK: - SPUStandardUserDriverDelegate

extension AppDelegate: SPUStandardUserDriverDelegate {

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if !handleShowingUpdate {
            DispatchQueue.main.async { [weak self] in
                self?.statusItemController.setAvailableUpdate(version: update.displayVersionString)
            }
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        // No-op — the badge clears when the update session ends.
    }

    func standardUserDriverWillFinishUpdateSession() {
        DispatchQueue.main.async { [weak self] in
            self?.statusItemController.setAvailableUpdate(version: nil)
        }
    }
}
