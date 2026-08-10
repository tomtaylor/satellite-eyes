import Foundation

extension FileManager {
    /// Resolved once, lazily and thread-safely, on first use.
    private static let _privateDataPath: String = {
        let manager = FileManager.default
        let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let identifier = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let path = appSupport.appendingPathComponent(identifier).path
        if !manager.fileExists(atPath: path) {
            try? manager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        return path
    }()

    var privateDataPath: String {
        FileManager._privateDataPath
    }

    func pathForPrivateFile(_ file: String) -> String {
        (privateDataPath as NSString).appendingPathComponent(file)
    }
}
