import Cocoa
import SwiftUI

// MARK: - SwiftUI View

struct ManageMapStylesView: View {
    @State private var mapTypes: [[String: Any]] = []
    @State private var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(mapTypes, id: \.mapStyleId) { mapType in
                    HStack {
                        Text(mapType["name"] as? String ?? "")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(mapType["source"] as? String ?? "")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tag(mapType["id"] as? String ?? "")
                }
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

                Button("Reset to Defaults") {
                    resetToDefaults()
                }
            }
            .padding(8)
        }
        .frame(width: 600, height: 400)
        .onAppear { loadMapTypes() }
    }

    private func loadMapTypes() {
        mapTypes = UserDefaults.standard.array(forKey: "mapTypes") as? [[String: Any]] ?? []
    }

    private func save() {
        UserDefaults.standard.set(mapTypes, forKey: "mapTypes")
    }

    private func addMapStyle() {
        let newStyle: [String: Any] = [
            "id": UUID().uuidString,
            "name": "New Map Style",
            "source": "",
            "maxZoom": 17,
        ]
        mapTypes.append(newStyle)
        save()
        selection = newStyle["id"] as? String
    }

    private func removeSelected() {
        guard let sel = selection else { return }
        mapTypes.removeAll { ($0["id"] as? String) == sel }
        save()
        selection = nil
    }

    private func resetToDefaults() {
        guard let path = Bundle.main.path(forResource: "Defaults", ofType: "plist"),
              let defaults = NSDictionary(contentsOfFile: path),
              let defaultMapTypes = defaults["mapTypes"] as? [[String: Any]] else { return }
        mapTypes = defaultMapTypes
        save()
    }
}

// MARK: - Dictionary helper for ForEach id

private extension Dictionary where Key == String, Value == Any {
    var mapStyleId: String { self["id"] as? String ?? UUID().uuidString }
}

// MARK: - Window Controller

@objc(TTManageMapStylesWindowController)
class ManageMapStylesWindowController: NSWindowController {

    private static func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: ManageMapStylesView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Manage Map Styles"
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
