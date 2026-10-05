import Foundation
import Testing

@testable import Satellite_Eyes

/// Tests for how tile fetch failures are classified: whether the place has no
/// tiles (try another), the failure is transient (retry the tile), or neither.
@Suite("Tile failure classification")
struct TileFailureKindTests {

    static let url = URL(string: "https://tiles.example.com/1/2/3.png")!

    // MARK: - HTTP status

    @Test("Missing tiles are unavailable", arguments: [204, 404, 410])
    func missingTilesAreUnavailable(statusCode: Int) {
        #expect(TileFailureKind(statusCode: statusCode) == .unavailable)
    }

    @Test("Overloaded servers are transient", arguments: [408, 429, 500, 502, 503, 504])
    func overloadedServersAreTransient(statusCode: Int) {
        #expect(TileFailureKind(statusCode: statusCode) == .transient)
    }

    @Test("Other client errors are fatal", arguments: [400, 401, 403, 405, 418])
    func otherClientErrorsAreFatal(statusCode: Int) {
        #expect(TileFailureKind(statusCode: statusCode) == .fatal)
    }

    @Test("A 404 is unavailable whatever came with it")
    func notFoundErrorIsUnavailable() {
        let error: any Error = TileFetchError.httpStatus(url: Self.url, statusCode: 404)
        #expect(TileFailureKind(error) == .unavailable)
    }

    // MARK: - Response content

    @Test("A placeholder tile is unavailable")
    func placeholderTileIsUnavailable() {
        #expect(TileFailureKind(TileFetchError.placeholderTile(url: Self.url)) == .unavailable)
    }

    /// A 200 with HTML is what a captive portal serves, so it must not send
    /// the rotation hunting for another place.
    @Test("A successful response that isn't an image is fatal")
    func nonImageResponseIsFatal() {
        let error = TileFetchError.invalidContentType(url: Self.url, contentType: "text/html; charset=utf-8")
        #expect(TileFailureKind(error) == .fatal)
        #expect(TileFailureKind(TileFetchError.undecodableImage(url: Self.url)) == .fatal)
    }

    // MARK: - Network errors

    @Test("Connectivity errors are transient", arguments: [
        URLError.Code.timedOut, .networkConnectionLost, .notConnectedToInternet,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
    ])
    func connectivityErrorsAreTransient(code: URLError.Code) {
        #expect(TileFailureKind(URLError(code)) == .transient)
    }

    @Test("Other network errors are fatal", arguments: [
        URLError.Code.badURL, .cancelled, .serverCertificateUntrusted, .secureConnectionFailed,
    ])
    func otherNetworkErrorsAreFatal(code: URLError.Code) {
        #expect(TileFailureKind(URLError(code)) == .fatal)
    }

    @Test("Unrecognised errors are fatal")
    func unrecognisedErrorsAreFatal() {
        #expect(TileFailureKind(CancellationError()) == .fatal)
    }
}
