import Foundation
import CryptoKit

extension String {
    func md5Digest() -> String {
        let data = Data(utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
