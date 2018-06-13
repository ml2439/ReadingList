import Foundation
import CoreData
import CloudKit

class BookUploader: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookUploader.self)

    func handleError(_ books: [CKRecordID: Book], _ ckError: CKError) {
        switch ckError.code {
        case .partialFailure:
            let errors = ckError.userInfo[CKPartialErrorsByItemIDKey] as! NSDictionary
            for error in errors {
                handleError(books, error.value as! CKError)
            }
        case .serverRecordChanged:
            let ancestor = ckError.ancestorRecord
            let server = ckError.serverRecord
            let client = ckError.clientRecord
            books[ckError.clientRecord!.recordID]?.updateFrom(ckRecord: server!)
        default: print("Error: \(ckError)")
        }
    }
    
    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: BookCloudKitRemote) {
        let ckRecords = books.map { book -> (Book, CKRecord) in
            if book.remoteIdentifier == nil {
                return (book, book.CKRecordForInsert(zoneID: remote.bookZoneID))
            } else {
                return (book, book.CKRecordForDifferentialUpdate())
            }
        }
        let booksByRemoteID = ckRecords.reduce(into: [CKRecordID: Book]()) { $0[$1.1.recordID] = $1.0 }

        remote.upload(ckRecords.map { $0.1 }) { remoteRecords, error in
            context.perform {
                if let error = error, case let ckError = error as? CKError {
                    self.handleError(booksByRemoteID, ckError!)
                }
                for ckRecord in remoteRecords! {
                    guard let localBook = booksByRemoteID[ckRecord.recordID] else { print("Mismatch of IDs."); continue }

                    // Assign the system fields and update the present values
                    localBook.storeCKRecordSystemFields(ckRecord)
                    localBook.remoteIdentifier = ckRecord.recordID.recordName
                    localBook.removePendingRemoteUpdateKeys(BookKey.all)
                }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            NSPredicate.or([NSPredicate(format: "%K == NULL", #keyPath(Book.remoteIdentifier)),
                            Book.pendingRemoteUpdatesPredicate])
        ])
        return fetchRequest
    }
}
