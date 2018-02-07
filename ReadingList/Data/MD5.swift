import Foundation

class MD5: Equatable {
    private let md5Data: Data
    
    init(data: Data) {
        md5Data = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        
        _ = md5Data.withUnsafeMutableBytes {md5Bytes in
            data.withUnsafeBytes {inputBytes in
                CC_MD5(inputBytes, CC_LONG(data.count), md5Bytes)
            }
        }
    }
    
    var hex: String {
        get {
            return md5Data.map { String(format: "%02hhx", $0) }.joined()
        }
    }
    
    var base64: String {
        get {
            return md5Data.base64EncodedString()
        }
    }
    
    static func ==(lhs: MD5, rhs: MD5) -> Bool {
        return lhs.md5Data == rhs.md5Data
    }
}
