import CoreLocation
import Foundation
import Testing

@testable import Satellite_Eyes

/// Tests for the Web Mercator projection in `MapTile`.
///
/// The expected tile coordinates were produced independently, with the
/// `asinh(tan(φ))` form of the projection rather than the
/// `log(tan(φ) + sec(φ))` form the app uses. The two are equivalent, so a
/// sign or factor slipping in one would not slip in the other.
@Suite("MapTile Web Mercator projection")
struct MapTileTests {

    /// The latitude the projection cuts off at, where the square world map
    /// runs out: atan(sinh(π)) in degrees.
    static let maxLatitude = 85.0511287798066

    // MARK: - Longitude

    @Test("Longitude spans the full tile grid", arguments: [0, 1, 8, 12, 19] as [UInt16])
    func longitudeSpansTheGrid(zoom: UInt16) {
        let width = pow(2.0, Double(zoom))

        #expect(MapTile.longitudeToX(-180, zoomLevel: zoom) == 0)
        #expect(MapTile.longitudeToX(180, zoomLevel: zoom) == width)
        #expect(MapTile.longitudeToX(0, zoomLevel: zoom).isApproximately(width / 2))
    }

    @Test("Longitude maps linearly")
    func longitudeMapsLinearly() {
        // A quarter of the way round the world is a quarter of the way across
        // the grid, which is what distinguishes the x axis from the y axis.
        #expect(MapTile.longitudeToX(-90, zoomLevel: 10).isApproximately(256))
        #expect(MapTile.longitudeToX(90, zoomLevel: 10).isApproximately(768))
    }

    // MARK: - Latitude

    @Test("The equator sits halfway down the grid", arguments: [0, 1, 8, 12, 19] as [UInt16])
    func equatorIsHalfwayDown(zoom: UInt16) {
        #expect(MapTile.latitudeToY(0, zoomLevel: zoom).isApproximately(pow(2.0, Double(zoom)) / 2))
    }

    @Test("The projection's latitude limits are the grid's top and bottom edges")
    func latitudeLimitsAreTheGridEdges() {
        let height = pow(2.0, 12.0)

        #expect(MapTile.latitudeToY(Self.maxLatitude, zoomLevel: 12).isApproximately(0, within: 1e-9))
        #expect(MapTile.latitudeToY(-Self.maxLatitude, zoomLevel: 12).isApproximately(height, within: 1e-9))
    }

    @Test("Latitude matches the asinh form of the projection",
          arguments: [-85.0, -60.0, -33.8688, -0.1807, 0.0, 12.5, 51.5074, 78.2232, 85.0])
    func latitudeMatchesAsinhForm(latitude: CLLocationDegrees) {
        let zoom: UInt16 = 14
        let expected = (1.0 - asinh(tan(latitude * .pi / 180.0)) / .pi) / 2.0 * pow(2.0, Double(zoom))

        #expect(MapTile.latitudeToY(latitude, zoomLevel: zoom).isApproximately(expected))
    }

    @Test("Y increases as latitude decreases")
    func yIncreasesSouthwards() {
        let latitudes = [80.0, 45.0, 10.0, 0.0, -10.0, -45.0, -80.0]
        let ys = latitudes.map { MapTile.latitudeToY($0, zoomLevel: 9) }

        #expect(ys == ys.sorted())
        #expect(Set(ys).count == ys.count)
    }

    // MARK: - Whole coordinates

    /// Expected values from the independent implementation described above.
    struct Landmark {
        let name: String
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
        let zoom: UInt16
        let x: Double
        let y: Double
        var tile: (x: UInt, y: UInt) { (UInt(x.rounded(.down)), UInt(y.rounded(.down))) }
    }

    static let landmarks = [
        Landmark(name: "London", latitude: 51.5074, longitude: -0.1278, zoom: 12,
                 x: 2046.54592, y: 1362.0245406335725),
        Landmark(name: "Sydney", latitude: -33.8688, longitude: 151.2093, zoom: 12,
                 x: 3768.4258133333333, y: 2457.9778619751473),
        Landmark(name: "Quito", latitude: -0.1807, longitude: -78.4678, zoom: 10,
                 x: 288.80270222222225, y: 512.5139919631835),
        Landmark(name: "Svalbard", latitude: 78.2232, longitude: 15.6267, zoom: 14,
                 x: 8903.18848, y: 2268.292808650458),
        Landmark(name: "Null Island", latitude: 0, longitude: 0, zoom: 8,
                 x: 128, y: 128),
    ]

    @Test("Coordinates project to known grid points", arguments: landmarks)
    func coordinatesProjectToKnownPoints(landmark: Landmark) {
        let coordinate = CLLocationCoordinate2D(latitude: landmark.latitude, longitude: landmark.longitude)
        let point = MapTile.coordinateToPoint(coordinate, zoomLevel: landmark.zoom)

        #expect(Double(point.x).isApproximately(landmark.x))
        #expect(Double(point.y).isApproximately(landmark.y))
    }

    @Test("A coordinate lands in the tile that contains it", arguments: landmarks)
    func coordinateLandsInContainingTile(landmark: Landmark) {
        let coordinate = CLLocationCoordinate2D(latitude: landmark.latitude, longitude: landmark.longitude)
        let tile = MapTile.tile(for: coordinate, source: "https://example.com/{z}/{x}/{y}.png",
                                zoomLevel: landmark.zoom)

        #expect(tile.x == landmark.tile.x)
        #expect(tile.y == landmark.tile.y)
        #expect(tile.z == landmark.zoom)
    }

    // MARK: - Round trips

    @Test("Unprojecting a tile's top left corner returns the same tile", arguments: landmarks)
    func topLeftCornerRoundTrips(landmark: Landmark) {
        let coordinate = CLLocationCoordinate2D(latitude: landmark.latitude, longitude: landmark.longitude)
        let tile = MapTile.tile(for: coordinate, source: "", zoomLevel: landmark.zoom)

        let corner = tile.topLeftCoordinate
        let again = MapTile.tile(for: corner, source: "", zoomLevel: landmark.zoom)

        #expect(again.x == tile.x)
        #expect(again.y == tile.y)
    }

    @Test("The top left corner is north west of everything else in the tile", arguments: landmarks)
    func topLeftCornerIsNorthWest(landmark: Landmark) {
        let coordinate = CLLocationCoordinate2D(latitude: landmark.latitude, longitude: landmark.longitude)
        let tile = MapTile.tile(for: coordinate, source: "", zoomLevel: landmark.zoom)
        let corner = tile.topLeftCoordinate

        // The landmark is somewhere inside the tile, so the corner is at or
        // north of it, and at or west of it.
        #expect(corner.latitude >= landmark.latitude)
        #expect(corner.longitude <= landmark.longitude)
    }

    @Test("Unprojecting a tile corner and projecting it back is the identity", arguments: landmarks)
    func cornerProjectionRoundTrips(landmark: Landmark) {
        let tile = landmark.tile
        let corner = MapTile.coordinate(forX: tile.x, y: tile.y, z: landmark.zoom)
        let point = MapTile.coordinateToPoint(corner, zoomLevel: landmark.zoom)

        #expect(Double(point.x).isApproximately(Double(tile.x)))
        #expect(Double(point.y).isApproximately(Double(tile.y)))
    }

    @Test("Tile (0, 0) at zoom 0 is the whole world")
    func zoomZeroIsTheWholeWorld() {
        let corner = MapTile.coordinate(forX: 0, y: 0, z: 0)

        #expect(corner.latitude.isApproximately(Self.maxLatitude, within: 1e-9))
        #expect(corner.longitude == -180)

        // ...and the tile below and right of it is the other corner.
        let opposite = MapTile.coordinate(forX: 1, y: 1, z: 0)
        #expect(opposite.latitude.isApproximately(-Self.maxLatitude, within: 1e-9))
        #expect(opposite.longitude == 180)
    }

    // MARK: - URL templates

    @Test("URL templates substitute x, y and z")
    func urlSubstitutesCoordinates() {
        let tile = MapTile(source: "https://tiles.example.com/{z}/{x}/{y}@2x.png", x: 2046, y: 1362, z: 12)

        #expect(tile.url == URL(string: "https://tiles.example.com/12/2046/1362@2x.png"))
    }

    @Test("URL templates substitute a quadkey")
    func urlSubstitutesQuadKey() {
        // Microsoft's own worked example: tile (3, 5) at level 3 is quadkey 213.
        let tile = MapTile(source: "https://ecn.t0.tiles.virtualearth.net/tiles/a{q}.jpeg", x: 3, y: 5, z: 3)

        #expect(tile.url == URL(string: "https://ecn.t0.tiles.virtualearth.net/tiles/a213.jpeg"))
    }

    @Test("A zoom 0 quadkey is empty")
    func quadKeyIsEmptyAtZoomZero() {
        let tile = MapTile(source: "https://example.com/{q}.jpeg", x: 0, y: 0, z: 0)

        #expect(tile.url == URL(string: "https://example.com/.jpeg"))
    }

    @Test("Every placeholder in a template is replaced")
    func everyPlaceholderIsReplaced() {
        let tile = MapTile(source: "https://example.com/{z}/{x}/{y}/{q}.png", x: 7, y: 3, z: 4)
        let url = tile.url.absoluteString

        #expect(!url.contains("{"))
        #expect(!url.contains("}"))
    }
}

extension MapTileTests.Landmark: CustomTestStringConvertible {
    var testDescription: String { name }
}

private extension Double {
    /// Comparison with a tolerance, since the projection is transcendental and
    /// the expected values come from a different arrangement of the same maths.
    func isApproximately(_ other: Double, within tolerance: Double = 1e-9) -> Bool {
        abs(self - other) <= tolerance * Swift.max(1, abs(self), abs(other))
    }
}
