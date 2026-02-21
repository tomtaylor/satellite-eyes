import Cocoa
import SwiftUI

// MARK: - SwiftUI View

struct PreferencesView: View {
    @AppStorage("selectedMapTypeId") private var selectedMapTypeId = "stamen-watercolor"
    @AppStorage("zoomLevel") private var zoomLevel = 15
    @AppStorage("selectedImageEffectId") private var selectedImageEffectId = "none"
    @State private var startAtLogin = LLManager.launchAtLogin()
    @State private var manageStylesController: ManageMapStylesWindowController?

    private var mapTypes: [[String: Any]] {
        UserDefaults.standard.array(forKey: "mapTypes") as? [[String: Any]] ?? []
    }

    private var imageEffects: [[String: Any]] {
        UserDefaults.standard.array(forKey: "imageEffectTypes") as? [[String: Any]] ?? []
    }

    var body: some View {
        Form {
            Picker("Map Style:", selection: $selectedMapTypeId) {
                ForEach(mapTypes, id: \.mapTypeId) { mapType in
                    Text(mapType["name"] as? String ?? "Unknown")
                        .tag(mapType["id"] as? String ?? "")
                }
            }

            Picker("Zoom Level:", selection: $zoomLevel) {
                ForEach(10...20, id: \.self) { level in
                    Text("\(level)").tag(level)
                }
            }

            Picker("Image Effect:", selection: $selectedImageEffectId) {
                ForEach(imageEffects, id: \.effectId) { effect in
                    Text(effect["name"] as? String ?? "Unknown")
                        .tag(effect["id"] as? String ?? "")
                }
            }

            Toggle("Run Satellite Eyes at Startup", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { newValue in
                    LLManager.setLaunchAtLogin(newValue)
                    startAtLogin = LLManager.launchAtLogin()
                }

            Button("Manage Map Styles...") {
                let controller = ManageMapStylesWindowController()
                controller.showWindow(nil)
                controller.window?.makeKeyAndOrderFront(nil)
                manageStylesController = controller
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Dictionary helpers for ForEach id

private extension Dictionary where Key == String, Value == Any {
    var mapTypeId: String { self["id"] as? String ?? UUID().uuidString }
    var effectId: String { self["id"] as? String ?? UUID().uuidString }
}

// MARK: - Window Controller

@objc(TTPreferencesWindowController)
class PreferencesWindowController: NSWindowController {

    private static func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        return window
    }

    override init(window: NSWindow?) {
        super.init(window: window ?? Self.makeWindow())
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.window = Self.makeWindow()
    }
}
