import Foundation
import CoreLocation
import CoreGraphics

@objc(TTMapTile)
class MapTile: NSObject {
    @objc let source: String
    @objc let x: UInt
    @objc let y: UInt
    @objc let z: UInt16
    @objc var imageData: Data?

    @objc init(source: String, x: UInt, y: UInt, z: UInt16) {
        self.source = source
        self.x = x
        self.y = y
        self.z = z
        super.init()
    }

    @objc var topLeftCoordinate: CLLocationCoordinate2D {
        MapTile.coordinate(forX: x, y: y, z: z)
    }

    @objc var url: URL {
        var urlString = source
        urlString = urlString.replacingOccurrences(of: "{x}", with: "\(x)")
        urlString = urlString.replacingOccurrences(of: "{y}", with: "\(y)")
        urlString = urlString.replacingOccurrences(of: "{z}", with: "\(z)")
        urlString = urlString.replacingOccurrences(of: "{q}", with: quadKey)
        return URL(string: urlString)!
    }

    @objc var urlRequest: URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        let version = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? "Unknown"
        request.addValue(
            "Satellite Eyes/\(version) (http://satelliteeyes.tomtaylor.co.uk)",
            forHTTPHeaderField: "User-Agent"
        )
        request.addValue("http://satelliteeyes.tomtaylor.co.uk", forHTTPHeaderField: "Referer")
        return request
    }

    @objc func newImageRef() -> CGImage? {
        guard let data = imageData else { return nil }
        let cfData = data as CFData
        guard let provider = CGDataProvider(data: cfData) else { return nil }
        return CGImage(
            jpegDataProviderSource: provider, decode: nil,
            shouldInterpolate: true, intent: .defaultIntent
        ) ?? CGImage(
            pngDataProviderSource: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )
    }

    private var quadKey: String {
        var result = ""
        for i in stride(from: Int(z), through: 1, by: -1) {
            let mask = 1 << (i - 1)
            var cell = 0
            if Int(x) & mask != 0 { cell += 1 }
            if Int(y) & mask != 0 { cell += 2 }
            result += "\(cell)"
        }
        return result
    }

    // MARK: - Class methods

    @objc(coordinateForX:y:z:)
    static func coordinate(forX x: UInt, y: UInt, z: UInt16) -> CLLocationCoordinate2D {
        let longitude = Double(x) / pow(2.0, Double(z)) * 360.0 - 180.0
        let n = Double.pi - 2.0 * Double.pi * Double(y) / pow(2.0, Double(z))
        let latitude = 180.0 / Double.pi * atan(0.5 * (exp(n) - exp(-n)))
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    @objc(tileForCoordinate:source:zoomLevel:)
    static func tile(for coordinate: CLLocationCoordinate2D, source: String, zoomLevel: UInt16) -> MapTile {
        let tileY = UInt(floor(latitudeToY(coordinate.latitude, zoomLevel: zoomLevel)))
        let tileX = UInt(floor(longitudeToX(coordinate.longitude, zoomLevel: zoomLevel)))
        return MapTile(source: source, x: tileX, y: tileY, z: zoomLevel)
    }

    @objc(coordinateToPoint:zoomLevel:)
    static func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, zoomLevel: UInt16) -> CGPoint {
        let pointY = latitudeToY(coordinate.latitude, zoomLevel: zoomLevel)
        let pointX = longitudeToX(coordinate.longitude, zoomLevel: zoomLevel)
        return CGPoint(x: pointX, y: pointY)
    }

    @objc(latitudeToY:zoomLevel:)
    static func latitudeToY(_ latitude: CLLocationDegrees, zoomLevel: UInt16) -> Double {
        (1.0 - log(tan(latitude * .pi / 180.0) + 1.0 / cos(latitude * .pi / 180.0)) / .pi)
            / 2.0 * pow(2.0, Double(zoomLevel))
    }

    @objc(longitudeToX:zoomLevel:)
    static func longitudeToX(_ longitude: CLLocationDegrees, zoomLevel: UInt16) -> Double {
        (longitude + 180.0) / 360.0 * pow(2.0, Double(zoomLevel))
    }
}
