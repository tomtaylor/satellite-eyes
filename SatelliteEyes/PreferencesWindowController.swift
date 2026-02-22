import Cocoa
import SwiftUI

// MARK: - SwiftUI View

struct PreferencesView: View {
    @AppStorage("selectedMapTypeId") private var selectedMapTypeId = "stamen-watercolor"
    @AppStorage("zoomLevel") private var zoomLevel = 15
    @AppStorage("selectedImageEffectId") private var selectedImageEffectId = "none"
    @AppStorage("useCurrentLocation") private var useCurrentLocation = true
    @AppStorage("randomLocationCategory") private var randomLocationCategory = ""
    @AppStorage("rotationIntervalSeconds") private var rotationIntervalSeconds = 86400
    @State private var startAtLogin = LoginItemManager.launchAtLogin
    @State private var manageStylesController: ManageMapStylesWindowController?
    @State private var builtInMapTypes: [[String: Any]] = []
    @State private var customMapTypes: [[String: Any]] = []

    private var allMapTypes: [[String: Any]] {
        builtInMapTypes + customMapTypes
    }

    private var imageEffects: [[String: Any]] {
        UserDefaults.standard.array(forKey: "imageEffectTypes") as? [[String: Any]] ?? []
    }

    private var locationSourceBinding: Binding<String> {
        Binding(
            get: {
                if useCurrentLocation { return "current_location" }
                if randomLocationCategory.isEmpty { return "random" }
                return randomLocationCategory
            },
            set: { newValue in
                if newValue == "current_location" {
                    useCurrentLocation = true
                    randomLocationCategory = ""
                } else {
                    useCurrentLocation = false
                    randomLocationCategory = newValue == "random" ? "" : newValue
                }
            }
        )
    }

    private var maxZoomForSelectedMap: Int {
        let mapType = allMapTypes.first { ($0["id"] as? String) == selectedMapTypeId }
        return (mapType?["maxZoom"] as? Int) ?? 20
    }

    var body: some View {
        Form {
            Toggle("Run Satellite Eyes at Startup", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { newValue in
                    LoginItemManager.setLaunchAtLogin(newValue)
                    startAtLogin = LoginItemManager.launchAtLogin
                }.padding(.bottom, 8)

            Picker("Location:", selection: locationSourceBinding) {
                Text("Your Location").tag("current_location")
                Text("Random Places").tag("random")
                Section {
                    Text("Only Airports").tag("airport")
                    Text("Only World Heritage Sites").tag("world_heritage_site")
                }
            }

            Picker("Change Every:", selection: $rotationIntervalSeconds) {
                Text("1 hour").tag(3600)
                Text("6 hours").tag(21600)
                Text("24 hours").tag(86400)
            }
            .disabled(useCurrentLocation)
            .padding(.bottom, 8)

            Picker("Map Style:", selection: $selectedMapTypeId) {
                Section("Built-in") {
                    ForEach(builtInMapTypes, id: \.mapTypeId) { mapType in
                        Text(mapType["name"] as? String ?? "Unknown")
                            .tag(mapType["id"] as? String ?? "")
                    }
                }
                if !customMapTypes.isEmpty {
                    Section("Custom") {
                        ForEach(customMapTypes, id: \.mapTypeId) { mapType in
                            Text(mapType["name"] as? String ?? "Unknown")
                                .tag(mapType["id"] as? String ?? "")
                        }
                    }
                }
            }
            .onChange(of: selectedMapTypeId) { _ in
                if zoomLevel > maxZoomForSelectedMap {
                    zoomLevel = maxZoomForSelectedMap
                }
            }

            Picker("Zoom Level:", selection: $zoomLevel) {
                ForEach(10...maxZoomForSelectedMap, id: \.self) { level in
                    Text("\(level)").tag(level)
                }
            }

            Picker("Image Effect:", selection: $selectedImageEffectId) {
                ForEach(imageEffects, id: \.effectId) { effect in
                    Text(effect["name"] as? String ?? "Unknown")
                        .tag(effect["id"] as? String ?? "")
                }
            }

            Button("Manage Custom Map Styles...") {
                if let existing = manageStylesController, existing.window?.isVisible == true {
                    existing.window?.makeKeyAndOrderFront(nil)
                } else {
                    let controller = ManageMapStylesWindowController()
                    controller.showWindow(nil)
                    controller.window?.makeKeyAndOrderFront(nil)
                    manageStylesController = controller
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { loadMapTypes() }
        .onReceive(NotificationCenter.default.publisher(for: .mapStylesDidChange)) { _ in
            loadMapTypes()
        }
    }

    private func loadMapTypes() {
        builtInMapTypes = MapStyle.builtInMapTypes()
        customMapTypes = UserDefaults.standard.array(forKey: "customMapTypes") as? [[String: Any]] ?? []
    }
}

// MARK: - Dictionary helpers for ForEach id

private extension Dictionary where Key == String, Value == Any {
    var mapTypeId: String { self["id"] as? String ?? UUID().uuidString }
    var effectId: String { self["id"] as? String ?? UUID().uuidString }
}

// MARK: - Window Controller

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
