import Cocoa
import SwiftUI

// MARK: - MapStyle Model

struct MapStyle: Identifiable, Equatable {
    var id: String
    var name: String
    var source: String
    var maxZoom: Int
    var upscaleRetina: Bool
    var extraKeys: [String: Any]
    
    init(id: String = UUID().uuidString, name: String = "New Map Style", source: String = "", maxZoom: Int = 17, upscaleRetina: Bool = false, extraKeys: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.source = source
        self.maxZoom = maxZoom
        self.upscaleRetina = upscaleRetina
        self.extraKeys = extraKeys
    }
    
    init(dictionary: [String: Any]) {
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.name = dictionary["name"] as? String ?? ""
        self.source = dictionary["source"] as? String ?? ""
        self.maxZoom = dictionary["maxZoom"] as? Int ?? 17
        self.upscaleRetina = dictionary["upscaleRetina"] as? Bool ?? false
        var extra = dictionary
        extra.removeValue(forKey: "id")
        extra.removeValue(forKey: "name")
        extra.removeValue(forKey: "source")
        extra.removeValue(forKey: "maxZoom")
        extra.removeValue(forKey: "upscaleRetina")
        self.extraKeys = extra
    }
    
    var dictionary: [String: Any] {
        var dict = extraKeys
        dict["id"] = id
        dict["name"] = name
        dict["source"] = source
        dict["maxZoom"] = maxZoom
        dict["upscaleRetina"] = upscaleRetina
        return dict
    }
    
    static func == (lhs: MapStyle, rhs: MapStyle) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.source == rhs.source && lhs.maxZoom == rhs.maxZoom && lhs.upscaleRetina == rhs.upscaleRetina
    }
    
    /// Load built-in map types from the bundle's BuiltInMapStyles.plist.
    static func builtInMapTypes() -> [[String: Any]] {
        guard let path = Bundle.main.path(forResource: "BuiltInMapStyles", ofType: "plist"),
              let mapTypes = NSArray(contentsOfFile: path) as? [[String: Any]] else { return [] }
        return mapTypes
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let mapStylesDidChange = Notification.Name("mapStylesDidChange")
}

// MARK: - SwiftUI View

struct ManageMapStylesView: View {
    @State private var mapStyles: [MapStyle] = []
    @State private var selection: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                List(selection: $selection) {
                    ForEach(mapStyles) { style in
                        Text(style.name.isEmpty ? "Untitled" : style.name)
                            .tag(style.id)
                    }
                }
                .frame(minWidth: 180, idealWidth: 220)
                
                VStack {
                    if let index = selectedIndex {
                        Form {
                            TextField("Name:", text: $mapStyles[index].name)
                            Section {
                                TextField("Source URL:", text: $mapStyles[index].source, axis: .vertical)
                                    .lineLimit(1...5)
                            } footer: {
                                Text("Use {x}, {y} and {z} as placeholders").foregroundStyle(.tertiary)
                            }
                            Picker("Max Zoom:", selection: $mapStyles[index].maxZoom) {
                                ForEach(10...22, id: \.self) { zoom in
                                    Text("\(zoom)").tag(zoom)
                                }
                            }
                            Section {
                                Toggle("Upscale for Retina", isOn: $mapStyles[index].upscaleRetina)
                            } footer: {
                                Text("Upscaling will use map tiles from a higher zoom level to increase the pixel density on retina displays. This will make any labels appear smaller.").foregroundStyle(.tertiary)
                            }
                        }
                        .padding()
                    } else {
                        Spacer()
                        Text(mapStyles.isEmpty ? "No custom map styles" : "Select a map style to edit")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(minWidth: 380, idealWidth: 380, maxHeight: .infinity)
            }
            
            Divider()
            
            HStack {
                Button(action: addMapStyle) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                
                Button(action: removeSelected) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selection == nil)
                
                Spacer()
            }
            .padding(8)
        }
        .frame(width: 600, height: 400)
        .onAppear { loadMapStyles() }
        .onChange(of: mapStyles) { _ in save() }
        .onChange(of: selection) { _ in save() }
    }
    
    private var selectedIndex: Int? {
        guard let selection else { return nil }
        return mapStyles.firstIndex { $0.id == selection }
    }
    
    private func loadMapStyles() {
        guard let array = UserDefaults.standard.array(forKey: "customMapTypes") as? [[String: Any]] else { return }
        mapStyles = array.map { MapStyle(dictionary: $0) }
    }
    
    private func save() {
        UserDefaults.standard.set(mapStyles.map(\.dictionary), forKey: "customMapTypes")
        NotificationCenter.default.post(name: .mapStylesDidChange, object: nil)
    }
    
    private func addMapStyle() {
        let style = MapStyle()
        mapStyles.append(style)
        selection = style.id
    }
    
    private func removeSelected() {
        guard let sel = selection else { return }
        mapStyles.removeAll { $0.id == sel }
        selection = nil
    }
}

// MARK: - Window Controller

class ManageMapStylesWindowController: NSWindowController {
    
    private static func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: ManageMapStylesView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Manage Custom Map Styles"
        window.styleMask = [.titled, .closable, .resizable]
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
