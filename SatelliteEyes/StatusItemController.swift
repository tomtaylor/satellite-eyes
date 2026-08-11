import Cocoa

/// Holds a `NotificationCenter` block-observer token and unregisters it when
/// released, so observers go away with their owner.
private final class ObserverToken {
    private let token: any NSObjectProtocol

    init(_ token: any NSObjectProtocol) {
        self.token = token
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {

    // MARK: - Private state

    private let statusItem: NSStatusItem
    private let upgradeMenuItem: NSMenuItem
    private let upgradeSeparator: NSMenuItem
    private let statusMenuItem: NSMenuItem
    private let forceMapUpdateMenuItem: NSMenuItem
    private let openInBrowserMenuItem: NSMenuItem

    private var hasLocation = false
    private var isActive = false
    private var didError = false
    private var mapLastUpdated: Date?
    private var availableUpdateVersion: String?
    private var currentLocationName: String?

    private var animationFrameIndex: UInt = 0
    private var animationTimer: Timer?
    private var observerTokens: [ObserverToken] = []

    // MARK: - Init

    override init() {
        let menu = NSMenu(title: "Menu")
        menu.autoenablesItems = false

        upgradeMenuItem = NSMenuItem(title: "", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
        upgradeMenuItem.isHidden = true
        menu.addItem(upgradeMenuItem)

        upgradeSeparator = NSMenuItem.separator()
        upgradeSeparator.isHidden = true
        menu.addItem(upgradeSeparator)

        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        forceMapUpdateMenuItem = NSMenuItem(title: "Refresh the map now",
                                           action: #selector(AppDelegate.forceMapUpdate(_:)),
                                           keyEquivalent: "")
        forceMapUpdateMenuItem.isEnabled = false
        menu.addItem(forceMapUpdateMenuItem)

        openInBrowserMenuItem = NSMenuItem(title: "Open in browser",
                                          action: #selector(AppDelegate.openMapInBrowser(_:)),
                                          keyEquivalent: "")
        openInBrowserMenuItem.isEnabled = false
        menu.addItem(openInBrowserMenuItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "About",
                                action: #selector(AppDelegate.showAbout(_:)),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open preferences...",
                                action: #selector(AppDelegate.showPreferences(_:)),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for updates...",
                                action: #selector(AppDelegate.checkForUpdates(_:)),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Exit",
                                action: #selector(AppDelegate.menuActionExit(_:)),
                                keyEquivalent: ""))

        statusItem = NSStatusBar.system.statusItem(withLength: 22)
        statusItem.menu = menu

        super.init()

        menu.delegate = self

        updateStatus()

        // Delivered on the main queue so the state below is only ever touched on
        // the main actor.
        observe(MapManager.startedLoadNotification) { controller, _ in
            controller.didError = false
            controller.isActive = true
        }

        observe(MapManager.finishedLoadNotification) { controller, _ in
            controller.didError = false
            controller.isActive = false
            controller.mapLastUpdated = Date()
        }

        observe(MapManager.failedLoadNotification) { controller, _ in
            controller.didError = true
            controller.isActive = false
        }

        observe(MapManager.locationUpdatedNotification) { controller, _ in
            controller.hasLocation = true
        }

        observe(MapManager.locationLostNotification) { controller, _ in
            controller.hasLocation = false
            controller.currentLocationName = nil
        }

        observe(MapManager.randomLocationSelectedNotification) { controller, locationName in
            controller.currentLocationName = locationName
        }
    }

    /// Observes `name` on the main queue, applies `handler` — passing the
    /// notification's object if it is a string — then refreshes the menu bar
    /// item. The observer is removed when this controller is released.
    private func observe(_ name: NSNotification.Name,
                         handler: @escaping @MainActor (StatusItemController, String?) -> Void) {
        let token = NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { [weak self] notification in
            let object = notification.object as? String
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self, object)
                self.updateStatus()
            }
        }
        observerTokens.append(ObserverToken(token))
    }

    // MARK: - Status update

    private func updateStatus() {
        if hasLocation {
            forceMapUpdateMenuItem.isEnabled = true
            enableOpenInBrowser()

            if isActive {
                startActivityAnimation()
            } else if didError {
                stopActivityAnimation()
                showError()
            } else {
                stopActivityAnimation()
                showNormal()
            }
        } else {
            stopActivityAnimation()
            showOffline()
            forceMapUpdateMenuItem.isEnabled = false
            disableOpenInBrowser()
        }
    }

    // MARK: - Update availability

    func setAvailableUpdate(version: String?) {
        availableUpdateVersion = version
        if let version {
            upgradeMenuItem.title = "Upgrade to \(version)"
            upgradeMenuItem.isHidden = false
            upgradeSeparator.isHidden = false
        } else {
            upgradeMenuItem.isHidden = true
            upgradeSeparator.isHidden = true
        }
        updateStatus()
    }

    // MARK: - Display states

    private var isRandomMode: Bool {
        !UserDefaults.standard.bool(forKey: "useCurrentLocation")
    }

    private func showOffline() {
        let image = NSImage(named: "status-icon-offline")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusMenuItem.title = isRandomMode ? "Picking a random location\u{2026}" : "Waiting for location fix"
    }

    private func showNormal() {
        let iconName = availableUpdateVersion != nil ? "status-icon-error" : "status-icon-online"
        let image = NSImage(named: iconName)
        image?.isTemplate = true
        statusItem.button?.image = image

        forceMapUpdateMenuItem.isHidden = false
        forceMapUpdateMenuItem.title = isRandomMode ? "Show a new location" : "Refresh the map now"

        if let updated = mapLastUpdated {
            let timeAgo = updated.distanceOfTimeInWords().lowercased()
            if isRandomMode, let name = currentLocationName {
                statusMenuItem.title = name
            } else {
                statusMenuItem.title = "Map updated \(timeAgo)"
            }
        } else {
            statusMenuItem.title = "Waiting for map update"
        }
    }

    private func showError() {
        let image = NSImage(named: "status-icon-error")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusMenuItem.title = "Problem updating the map"
    }

    // MARK: - Activity animation

    private func startActivityAnimation() {
        animationFrameIndex = 0
        updateActivityImage()

        animationTimer?.invalidate()
        animationTimer = Timer(timeInterval: 0.25, target: self,
                               selector: #selector(updateActivityImage),
                               userInfo: nil, repeats: true)
        animationTimer?.tolerance = 0.01
        RunLoop.current.add(animationTimer!, forMode: .default)

        statusMenuItem.title = "Updating the map"
    }

    @objc private func updateActivityImage() {
        let image = NSImage(named: "status-icon-activity-\(animationFrameIndex)")
        image?.isTemplate = true
        statusItem.button?.image = image
        animationFrameIndex = animationFrameIndex >= 3 ? 0 : animationFrameIndex + 1
    }

    private func stopActivityAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Open in browser

    private func enableOpenInBrowser() {
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        openInBrowserMenuItem.isEnabled = appDelegate?.visibleMapBrowserURL != nil
    }

    private func disableOpenInBrowser() {
        openInBrowserMenuItem.isEnabled = false
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateStatus()
    }
}
