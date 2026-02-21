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
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

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
                self?.shutdownWithLocationError()
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
        NSUserDefaultsController.shared.initialValues = defaults

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
            doHelloAlert()
            doStartupAlert()
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    private func doHelloAlert() {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = "Welcome to Satellite Eyes"
        alert.informativeText = """
            Satellite Eyes is now running in the status bar at the top right of your screen.

            It will automatically change your desktop wallpaper to your current location.

            You can adjust the preferences by clicking on the icon.
            """
        alert.runModal()
    }

    private func doStartupAlert() {
        let alert = NSAlert()
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        alert.messageText = "Run Satellite Eyes at Startup?"
        alert.informativeText = "Satellite Eyes works best when it's run in the background all the time. Do you want it to run automatically at startup?"

        if alert.runModal() == .alertFirstButtonReturn {
            LoginItemManager.setLaunchAtLogin(true)
        }
    }

    private func shutdownWithLocationError() {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = "Satellite Eyes Will Quit"
        alert.informativeText = """
            Satellite Eyes needs permission to access your location, or it can't load the correct map.

            You can enable Location Services from the Security & Privacy pane in System Preferences, \
            and then restart the application.
            """
        alert.runModal()
        NSApp.terminate(nil)
    }
}
