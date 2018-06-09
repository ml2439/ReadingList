import Foundation
import CoreData
import CloudKit

extension CKRecord: RemoteRecord {
    public var id: RemoteRecordID? { //swiftlint:disable:this lower_acl_than_parent
        return self.recordID.recordName
    }
}

extension Book {

    // Pending remote deletion flag should never get un-done. Hence, it cannot be set publicly, and can
    // only be set to "true" via a public function.
    @NSManaged private(set) var pendingRemoteDeletion: Bool
    func markForDeletion() { pendingRemoteDeletion = true }

    @NSManaged var remoteIdentifier: String?
    @NSManaged private var ckRecordEncodedSystemFields: Data?

    func getStoredCKRecord() -> CKRecord? {
        guard let systemFieldsData = ckRecordEncodedSystemFields else { return nil }
        return CKRecord(systemFieldsData: systemFieldsData)!
    }

    func update(from ckRecord: CKRecord) {
        ckRecordEncodedSystemFields = ckRecord.encodedSystemFields()
        remoteIdentifier = ckRecord.id

        // A CKRecord will only include a delta of the record; rather than assign all values from it,
        // we should assign those values which correspond to present keys.
        let presentKeys = ckRecord.allKeys()
        func ifKeyPresent(_ key: String, perform: (Any?) -> Void) {
            guard presentKeys.contains(key) else { return }
            perform(ckRecord.value(forKey: key))
        }
        ifKeyPresent("title") { title = $0 as! String }
        ifKeyPresent("googleBooksId") { googleBooksId = $0 as? String }
    }

    static var notMarkedForDeletion: NSPredicate {
        return NSPredicate(format: "%K == false", #keyPath(Book.pendingRemoteDeletion))
    }

    static func withRemoteIdentifiers(_ ids: [RemoteRecordID]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}

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
