import Testing

@testable import Satellite_Eyes

/// Tests for choosing random places from a set of "Interesting Sights" categories.
@Suite("Location store")
struct LocationStoreTests {

    @Test("The bundled list has places in every category")
    func bundledListHasEveryCategory() {
        #expect(Set(LocationStore.categories)
            == ["airport", "world_heritage_site", "solar_farm", "salt_pond_or_mine"])
    }

    @Test("Only places in the chosen categories are returned")
    func filtersToChosenCategories() {
        let chosen: Set<String> = ["airport", "solar_farm"]
        let places = LocationStore.locations(inCategories: chosen)
        #expect(!places.isEmpty)
        #expect(places.allSatisfy { chosen.contains($0.category) })
        #expect(Set(places.map(\.category)) == chosen)
    }

    @Test("No categories means every place")
    func emptySetMeansEveryPlace() {
        #expect(LocationStore.locations(inCategories: []).count == LocationStore.allLocations.count)
    }

    @Test("A random place comes from the chosen categories and skips excluded names")
    func randomPlaceRespectsCategoriesAndExclusions() throws {
        let chosen: Set<String> = ["world_heritage_site"]
        let names = Set(LocationStore.locations(inCategories: chosen).map(\.name))
        let kept = try #require(names.first)
        let place = try #require(LocationStore.randomLocation(inCategories: chosen,
                                                              excluding: names.subtracting([kept])))
        #expect(place.name == kept)
        #expect(place.category == "world_heritage_site")
    }
}
