import Foundation
import CoreData
import CloudKit

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

    func toCKRecord(bookZoneID: CKRecordZoneID) -> CKRecord {
        let ckRecord: CKRecord
        // If the CKRecord already exists, create the record from the stored system fields,
        // and add any modified keys to the record.
        let uploadAllKeys: Bool
        if let systemFieldsData = ckRecordEncodedSystemFields {
            ckRecord = CKRecord(systemFieldsData: systemFieldsData)!
            uploadAllKeys = false
        } else {
            // Otherwise, create a new CKRecord and store the generated remote ID
            ckRecord = CKRecord(recordType: "Book", zoneID: bookZoneID)
            remoteIdentifier = ckRecord.recordID.recordName
            uploadAllKeys = true
        }

        // We want to include only the modified keys, unless this is a new CKRecord, in which case
        // we should include all keys.
        let modifiedKeys = modifiedKeysPendingRemoteUpdate
        func setValue(_ value: Any?, ifModified: BookKey, forKey key: String) {
            if uploadAllKeys || modifiedKeys.contains(ifModified) {
                ckRecord.setValue(value, forKey: key)
            }
        }

        setValue(title, ifModified: .title, forKey: "title")
        setValue(googleBooksId, ifModified: .googleBooksId, forKey: "googleBooksId")
        setValue(isbn13, ifModified: .isbn13, forKey: "isbn13")
        setValue(pageCount, ifModified: .pageCount, forKey: "pageCount")
        setValue(publicationDate, ifModified: .publicationDate, forKey: "publicationDate")
        setValue(bookDescription, ifModified: .bookDescription, forKey: "bookDescription")
        setValue(notes, ifModified: .notes, forKey: "notes")
        setValue(currentPage, ifModified: .currentPage, forKey: "currentPage")
        setValue(sort, ifModified: .sort, forKey: "sort")
        setValue(startedReading, ifModified: .startedReading, forKey: "startedReading")
        setValue(finishedReading, ifModified: .finishedReading, forKey: "finishedReading")

        if uploadAllKeys || modifiedKeys.contains(.coverImage) {
            let imageFilePath = URL.temporary()
            FileManager.default.createFile(atPath: imageFilePath.path, contents: coverImage, attributes: nil)
            ckRecord.setValue(CKAsset(fileURL: imageFilePath), forKey: "coverImage")
        }

        return ckRecord
    }

    func update(from ckRecord: CKRecord) {
        ckRecordEncodedSystemFields = ckRecord.encodedSystemFields()
        remoteIdentifier = ckRecord.recordID.recordName

        // A CKRecord will only include a delta of the record; rather than assign all values from it,
        // we should assign those values which correspond to present keys.
        let presentKeys = ckRecord.allKeys()
        func ifKeyPresent(_ key: String, perform: (Any?) -> Void) {
            guard presentKeys.contains(key) else { return }
            perform(ckRecord.value(forKey: key))
        }
        ifKeyPresent("title") { title = $0 as! String }
        ifKeyPresent("googleBooksId") { googleBooksId = $0 as? String }
        ifKeyPresent("isbn13") { isbn13 = $0 as? String }
        ifKeyPresent("pageCount") { pageCount = $0 as? NSNumber }
        ifKeyPresent("publicationDate") { publicationDate = $0 as? Date }
        ifKeyPresent("bookDescription") { bookDescription = $0 as? String }
        ifKeyPresent("notes") { notes = $0 as? String }
        ifKeyPresent("currentPage") { currentPage = $0 as? NSNumber }
        ifKeyPresent("sort") { sort = $0 as? NSNumber }
        ifKeyPresent("startedReading") { startedReading = $0 as? Date }
        ifKeyPresent("finishedReading") { finishedReading = $0 as? Date }
        ifKeyPresent("coverImage") {
            if let imageAsset = $0 as? CKAsset {
                coverImage = FileManager.default.contents(atPath: imageAsset.fileURL.path)
            } else {
                coverImage = nil
            }
        }

        // Set the read state according to the resulting reading dates, if the CKRecord involved changes to the dates
        if presentKeys.contains("startedReading") || presentKeys.contains("finishedReading") {
            if startedReading != nil && finishedReading != nil {
                readState = .finished
            } else if startedReading != nil && finishedReading == nil {
                readState = .reading
            } else if startedReading == nil && finishedReading == nil {
                readState = .toRead
            }
        }
    }

    static var notMarkedForDeletion: NSPredicate {
        return NSPredicate(format: "%K == false", #keyPath(Book.pendingRemoteDeletion))
    }

    static func withRemoteIdentifiers(_ ids: [String]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}
