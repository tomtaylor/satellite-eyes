import Cocoa

@objc(TTStatusItemController)
class StatusItemController: NSObject, NSMenuDelegate {

    // MARK: - Private state

    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem
    private let forceMapUpdateMenuItem: NSMenuItem
    private let openInBrowserMenuItem: NSMenuItem

    private var hasLocation = false
    private var isActive = false
    private var didError = false
    private var mapLastUpdated: Date?

    private var animationFrameIndex: UInt = 0
    private var animationTimer: Timer?

    // MARK: - Init

    override init() {
        let menu = NSMenu(title: "Menu")
        menu.autoenablesItems = false

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

        let nc = NotificationCenter.default

        nc.addObserver(forName: MapManager.startedLoadNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.didError = false
            self.isActive = true
            DispatchQueue.main.async { self.updateStatus() }
        }

        nc.addObserver(forName: MapManager.finishedLoadNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.didError = false
            self.isActive = false
            self.mapLastUpdated = Date()
            DispatchQueue.main.async { self.updateStatus() }
        }

        nc.addObserver(forName: MapManager.failedLoadNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.didError = true
            self.isActive = false
            DispatchQueue.main.async { self.updateStatus() }
        }

        nc.addObserver(forName: MapManager.locationUpdatedNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.hasLocation = true
            DispatchQueue.main.async { self.updateStatus() }
        }

        nc.addObserver(forName: MapManager.locationLostNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.hasLocation = false
            DispatchQueue.main.async { self.updateStatus() }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    // MARK: - Display states

    private func showOffline() {
        let image = NSImage(named: "status-icon-offline")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusMenuItem.title = "Waiting for location fix"
    }

    private func showNormal() {
        let image = NSImage(named: "status-icon-online")
        image?.isTemplate = true
        statusItem.button?.image = image

        forceMapUpdateMenuItem.isHidden = false

        if let updated = mapLastUpdated {
            statusMenuItem.title = "Map updated \((updated as NSDate).distanceOfTimeInWords().lowercased())"
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
