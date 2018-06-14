import Foundation
import CloudKit

extension CKRecord {
    convenience init?(systemFieldsData: Data) {
        let coder = NSKeyedUnarchiver(forReadingWith: systemFieldsData)
        coder.requiresSecureCoding = true
        self.init(coder: coder)
        coder.finishDecoding()
    }

    func encodedSystemFields() -> Data {
        let data = NSMutableData()
        let coder = NSKeyedArchiver(forWritingWith: data)
        coder.requiresSecureCoding = true
        encodeSystemFields(with: coder)
        coder.finishEncoding()
        return data as Data
    }

    static func valuesAreEqual(left: CKRecordValue?, right: CKRecordValue?) -> Bool {
        if left == nil && right == nil { return true }
        guard let left = left, let right = right else { return false }

        if let leftString = left as? NSString {
            return leftString == right as? NSString
        }
        if let leftNumber = left as? NSNumber {
            return leftNumber == right as? NSNumber
        }
        if let leftDate = left as? NSDate {
            return leftDate == right as? NSDate
        }
        if let leftData = left as? NSData {
            return leftData == right as? NSData
        }
        if let leftArray = left as? NSArray {
            return leftArray == right as? NSArray
        }
        if left is CKAsset && right is CKAsset {
            // TODO: We don't have a way to compare CKAsset values unfortunately
            return true
        }

        fatalError("Unexpected data type in CKRecordValue comparison.")
    }
}

extension CKError {
    // TODO: Complete
    var isFatal: Bool {
        switch code {
        case .invalidArguments:
            return true
        default:
            return false
        }
    }
}
