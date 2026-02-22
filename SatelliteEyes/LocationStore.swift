import CoreLocation

enum LocationStore {

    struct NamedLocation {
        let name: String
        let category: String
        let coordinate: CLLocationCoordinate2D
    }

    static let allLocations: [NamedLocation] = {
        guard let url = Bundle.main.url(forResource: "Locations", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let entries = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
        else { return [] }

        return entries.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let category = dict["category"] as? String,
                  let lat = dict["latitude"] as? Double,
                  let lon = dict["longitude"] as? Double
            else { return nil }
            return NamedLocation(name: name, category: category,
                                 coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }()

    static let categories: [String] = {
        Array(Set(allLocations.map(\.category))).sorted()
    }()

    static func locations(forCategory category: String) -> [NamedLocation] {
        if category.isEmpty { return allLocations }
        return allLocations.filter { $0.category == category }
    }

    static func randomLocation(forCategory category: String) -> NamedLocation? {
        locations(forCategory: category).randomElement()
    }
}
