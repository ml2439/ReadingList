import Foundation
import CloudKit

extension CKRecord: RemoteRecord {
    public var id: RemoteRecordID? { //swiftlint:disable:this lower_acl_than_parent
        return self.recordID.recordName
    }
}

extension Book {
    func toCkRecord() -> CKRecord {
        let ckRecord = CKRecord(recordType: "Book")
        ckRecord.setValue(title, forKey: "title")
        ckRecord.setValue(googleBooksId, forKey: "googleBooksId")
        return ckRecord
    }

    func updateFromCkRecord(_ ckRecord: CKRecord) {
        title = ckRecord.value(forKey: "title") as! String
        googleBooksId = ckRecord.value(forKey: "googleBooksId") as? String
    }
}
