import Foundation
import CryptoKit

extension NSString {
    @objc func md5Digest() -> String {
        let data = Data((self as String).utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension NSData {
    @objc func md5Digest() -> String {
        let digest = Insecure.MD5.hash(data: self as Data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
