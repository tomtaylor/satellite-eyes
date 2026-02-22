import Foundation
import ServiceManagement
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SatelliteEyes", category: "LoginItemManager")

enum LoginItemManager {

    static var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("SMAppService register/unregister failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
