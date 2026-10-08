import Cocoa
import SwiftUI

// MARK: - SwiftUI View

struct PreferencesView: View {
    @AppStorage("selectedMapTypeId") private var selectedMapTypeId = "google-satellite"
    @AppStorage("zoomLevel") private var zoomLevel = 15
    @AppStorage("selectedImageEffectId") private var selectedImageEffectId = "none"
    @AppStorage("useCurrentLocation") private var useCurrentLocation = true
    @AppStorage("rotationIntervalSeconds") private var rotationIntervalSeconds = 86400
    // @AppStorage can't hold an array on macOS 13, so this is read and written by hand.
    @State private var randomLocationCategories = PreferencesView.loadedRandomLocationCategories()
    @State private var startAtLogin = LoginItemManager.launchAtLogin
    @State private var manageStylesController: ManageMapStylesWindowController?
    // Loaded eagerly, not in onAppear: this view's body is built as soon as the
    // window controller is created at launch, and an empty picker at that point
    // makes the stored selection look like an invalid tag.
    @State private var imageEffects = PreferencesView.loadedImageEffects()
    @State private var builtInMapTypes = MapStyle.builtInMapTypes()
    @State private var customMapTypes = PreferencesView.loadedCustomMapTypes()

    private var allMapTypes: [[String: Any]] {
        builtInMapTypes + customMapTypes
    }

    /// The "Interesting Sights" categories, in display order. A new category in
    /// `Locations.plist` needs a row here and in `Defaults.plist`.
    private static let locationCategories: [(id: String, name: String)] = [
        ("airport", "Airports"),
        ("world_heritage_site", "World Heritage Sites"),
        ("solar_farm", "Solar Farms"),
        ("salt_pond_or_mine", "Salt Ponds & Mines"),
    ]

    private func categoryBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { randomLocationCategories.contains(id) },
            set: { isOn in
                var categories = randomLocationCategories
                if isOn { categories.insert(id) } else { categories.remove(id) }
                // The checkbox for the last category is disabled, but never
                // store an empty set, whatever the route here.
                guard !categories.isEmpty else { return }
                randomLocationCategories = categories
                let ordered = Self.locationCategories.map(\.id).filter(categories.contains)
                UserDefaults.standard.set(ordered, forKey: "randomLocationCategories")
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
                }.padding(.bottom, 16)

            Picker("Location:", selection: $useCurrentLocation) {
                Text("Your Location").tag(true)
                Text("Interesting Sights").tag(false)
            }
            .pickerStyle(.radioGroup)

            // Indented under the "Interesting Sights" radio button's label.
            // Disabled rather than hidden so the choices survive a trip to
            // "Your Location" and the window keeps its size.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.locationCategories, id: \.id) { category in
                    let binding = categoryBinding(category.id)
                    Toggle(category.name, isOn: binding)
                        .toggleStyle(.checkbox)
                        .disabled(binding.wrappedValue && randomLocationCategories.count == 1)
                }
            }
            .padding(.leading, 20)
            .disabled(useCurrentLocation)

            Picker("Change Every:", selection: $rotationIntervalSeconds) {
                Text("1 hour").tag(3600)
                Text("6 hours").tag(21600)
                Text("24 hours").tag(86400)
            }
            .fixedSize()
            .disabled(useCurrentLocation)
            .padding(.top, 6)
            .padding(.bottom, 16)

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

    /// The stored categories, limited to ones this version knows about and
    /// never empty, so at least one checkbox is always ticked.
    private static func loadedRandomLocationCategories() -> Set<String> {
        let known = Set(locationCategories.map(\.id))
        let stored = Set(UserDefaults.standard.stringArray(forKey: "randomLocationCategories") ?? [])
            .intersection(known)
        return stored.isEmpty ? known : stored
    }

    private static func loadedCustomMapTypes() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: "customMapTypes") as? [[String: Any]] ?? []
    }

    private static func loadedImageEffects() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: "imageEffectTypes") as? [[String: Any]] ?? []
    }

    private func loadMapTypes() {
        builtInMapTypes = MapStyle.builtInMapTypes()
        customMapTypes = Self.loadedCustomMapTypes()
        imageEffects = Self.loadedImageEffects()
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
