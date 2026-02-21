import Foundation

extension FileManager {
    private static var _privateDataPath: String?

    var privateDataPath: String {
        if let cached = FileManager._privateDataPath { return cached }
        let appSupport = urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let identifier = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
        let path = appSupport.appendingPathComponent(identifier).path
        if !fileExists(atPath: path) {
            try? createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        FileManager._privateDataPath = path
        return path
    }

    func pathForPrivateFile(_ file: String) -> String {
        (privateDataPath as NSString).appendingPathComponent(file)
    }
}
