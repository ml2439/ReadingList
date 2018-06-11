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
}
