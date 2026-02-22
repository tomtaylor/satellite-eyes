import Cocoa
import CoreImage
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SatelliteEyes", category: "MapImage")

private let validTileContentTypes: Set<String> = ["image/jpeg", "image/png"]

enum TileFetchError: LocalizedError {
    case invalidContentType(url: URL, contentType: String?)
    case undecodableImage(url: URL)

    var errorDescription: String? {
        switch self {
        case .invalidContentType(let url, let contentType):
            return "Tile at \(url) returned unexpected content type: \(contentType ?? "unknown")"
        case .undecodableImage(let url):
            return "Tile at \(url) could not be decoded as an image"
        }
    }
}

class MapImage {
    private let tileRect: CGRect
    private let tileScale: Float
    private let zoomLevel: UInt16
    private let source: String
    private let imageEffect: NSDictionary
    private let tiles: [[MapTile]]
    private let pixelShift: CGPoint
    private let logoImage: NSImage?
    private let tileSize: UInt

    private static let sharedTileSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    init(tileRect: CGRect, tileScale: Float, zoomLevel: UInt16,
               source: String, effect: NSDictionary, logo: NSImage?) {
        self.tileRect = tileRect
        self.tileScale = tileScale
        self.zoomLevel = zoomLevel
        self.source = source
        self.imageEffect = effect
        self.logoImage = logo
        self.tileSize = UInt(256 * tileScale)

        var dummy: Float = 0
        let shiftX = Int(floor(modff(Float(tileRect.origin.x), &dummy) * Float(self.tileSize)))
        let shiftY = Int(self.tileSize) - Int(floor(modff(Float(tileRect.origin.y), &dummy) * Float(self.tileSize)))
        self.pixelShift = CGPoint(x: shiftX, y: shiftY)

        var tilesArray: [[MapTile]] = []
        let bottomY = Int(floor(tileRect.origin.y))
        let topY = Int(floor(tileRect.origin.y - tileRect.size.height))
        let leftX = Int(floor(tileRect.origin.x))
        let rightX = Int(floor(tileRect.origin.x + tileRect.size.width))

        var currentY = bottomY
        while currentY >= topY {
            var row: [MapTile] = []
            var currentX = leftX
            while currentX <= rightX {
                row.append(MapTile(source: source, x: UInt(currentX), y: UInt(currentY), z: zoomLevel))
                currentX += 1
            }
            tilesArray.append(row)
            currentY -= 1
        }
        self.tiles = tilesArray
    }

    // MARK: - Public API

    var fileURL: URL {
        let fileName = "map-\(uniqueHash).png"
        let path = FileManager.default.pathForPrivateFile(fileName)
        return URL(fileURLWithPath: path)
    }

    func fetchTilesWithSuccess(_ success: @escaping (URL) -> Void,
                                     failure: @escaping (Error) -> Void,
                                     skipCache: Bool) {
        Task.detached { [self] in
            do {
                let url = try await self.fetchTiles(skipCache: skipCache)
                success(url)
            } catch {
                failure(error)
            }
        }
    }

    func fetchTiles(skipCache: Bool) async throws -> URL {
        let fileURL = self.fileURL

        if !skipCache {
            log.debug("Looking up file at: \(fileURL.path, privacy: .public)")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                log.debug("Map image already cached: \(fileURL.path, privacy: .public)")
                return fileURL
            }
        }

        log.debug("Not found or skipping cache, fetching: \(fileURL.path, privacy: .public)")

        try await withThrowingTaskGroup(of: Void.self) { group in
            for row in tiles {
                for tile in row {
                    group.addTask {
                        let (data, response) = try await Self.sharedTileSession.data(for: tile.urlRequest)
                        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
                        let mimeType = contentType.flatMap { $0.split(separator: ";").first.map(String.init) }
                        if let mimeType, !validTileContentTypes.contains(mimeType) {
                            throw TileFetchError.invalidContentType(url: tile.url, contentType: contentType)
                        }
                        tile.imageData = data
                        guard tile.newImageRef() != nil else {
                            throw TileFetchError.undecodableImage(url: tile.url)
                        }
                    }
                }
            }
            try await group.waitForAll()
        }

        return writeImageData()
    }

    // MARK: - Private

    private var uniqueHash: String {
        let key = String(format: "%@_%.1f_%.1f_%.2f_%.2f_%.2f_%@_%u",
                         source,
                         tileRect.origin.x, tileRect.origin.y,
                         tileRect.size.width, tileRect.size.height,
                         tileScale,
                         imageEffect.description,
                         zoomLevel)
        return key.md5Digest()
    }

    private func writeImageData() -> URL {
        let width = Int(floor(tileRect.size.width * CGFloat(tileSize)))
        let height = Int(floor(tileRect.size.height * CGFloat(tileSize)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = (width * bitsPerComponent * bytesPerPixel + 7) / 8

        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            fatalError("Failed to create bitmap context")
        }

        // Draw tiles
        for (rowIndex, row) in tiles.enumerated() {
            for (tileIndex, tile) in row.enumerated() {
                if let tileImage = tile.newImageRef() {
                    let drawX = CGFloat(tileIndex) * CGFloat(tileSize) - pixelShift.x
                    let drawY = CGFloat(rowIndex) * CGFloat(tileSize) - pixelShift.y
                    context.draw(tileImage, in: CGRect(x: drawX, y: drawY,
                                                        width: CGFloat(tileSize), height: CGFloat(tileSize)))
                }
            }
        }

        guard let imageRef = context.makeImage() else {
            fatalError("Failed to create image from context")
        }

        // Apply CIFilter effects
        let ciContext = CIContext()
        let ciInput = CIImage(cgImage: imageRef)
        var ciOutput = ciInput

        // Affine clamp so blur/gloom type filters work at edges
        if let clampFilter = CIFilter(name: "CIAffineClamp") {
            clampFilter.setDefaults()
            clampFilter.setValue(ciInput, forKey: kCIInputImageKey)
            clampFilter.setValue(NSAffineTransform(), forKey: kCIInputTransformKey)
            if let output = clampFilter.outputImage {
                ciOutput = output
            }
        }

        // Apply effect filters
        if let filters = imageEffect["filters"] as? [[String: Any]] {
            for filterDef in filters {
                guard let name = filterDef["name"] as? String,
                      let imageFilter = CIFilter(name: name) else { continue }
                imageFilter.setDefaults()
                imageFilter.setValue(ciOutput, forKey: kCIInputImageKey)

                if let parameters = filterDef["parameters"] as? [[String: Any]] {
                    for param in parameters {
                        guard let paramName = param["name"] as? String else { continue }
                        let value = scaledFilterValue(param["value"] as Any, key: paramName)
                        imageFilter.setValue(value, forKey: paramName)
                    }
                }
                if let output = imageFilter.outputImage {
                    ciOutput = output
                }
            }
        }

        // Render filtered image back
        if let tiledImage = ciContext.createCGImage(ciOutput, from: ciInput.extent) {
            context.draw(tiledImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Draw logo
        if let logo = logoImage, let tiffData = logo.tiffRepresentation,
           let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil),
           let logoRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            let margin: CGFloat = 10
            let logoWidth = CGFloat(logoRef.width)
            let logoHeight = CGFloat(logoRef.height)
            context.draw(logoRef, in: CGRect(
                x: CGFloat(width) - logoWidth - margin,
                y: margin,
                width: logoWidth,
                height: logoHeight
            ))
        }

        // Save to PNG
        guard let finalImage = context.makeImage() else {
            fatalError("Failed to create final image")
        }
        let outputURL = self.fileURL
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL, "public.png" as CFString, 1, nil
        ) else {
            fatalError("Failed to create image destination")
        }
        CGImageDestinationAddImage(destination, finalImage, nil)
        CGImageDestinationFinalize(destination)

        return outputURL
    }

    private func scaledFilterValue(_ value: Any, key: String) -> Any {
        if [kCIInputRadiusKey, kCIInputScaleKey, kCIInputWidthKey].contains(key),
           let number = value as? NSNumber {
            return NSNumber(value: number.floatValue * tileScale)
        }
        return value
    }
}
