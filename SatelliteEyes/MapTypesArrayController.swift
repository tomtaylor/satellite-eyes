import Cocoa

@objc(TTMapTypesArrayController)
class MapTypesArrayController: NSArrayController {
    override func newObject() -> Any {
        [
            "id": UUID().uuidString,
            "mapZoom": 17,
            "name": "New Map Style",
        ] as NSDictionary
    }
}
