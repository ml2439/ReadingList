import Foundation
import CoreData
import CloudKit

class BookInserter: BookUpstreamChangeProcessor {

    init(_ context: NSManagedObjectContext, _ remote: BookCloudKitRemote) {
        self.context = context
        self.remote = remote
    }

    let debugDescription = String(describing: BookInserter.self)
    let context: NSManagedObjectContext
    let remote: BookCloudKitRemote

    func handleError(_ books: [CKRecord.ID: Book], _ ckError: CKError) {
        switch ckError.code {
        case .partialFailure:
            let errors = ckError.userInfo[CKPartialErrorsByItemIDKey] as! NSDictionary
            for error in errors {
                handleError(books, error.value as! CKError)
            }
        case .serverRecordChanged:
            let server = ckError.serverRecord
            books[ckError.clientRecord!.recordID]?.updateFrom(serverRecord: server!)
        default: print("Error: \(ckError)")
        }
    }

    func processLocalChanges(_ books: [Book], completion: @escaping () -> Void) {

        let booksAndCKRecords = books.map { book -> (book: Book, ckRecord: CKRecord) in
            (book, book.CKRecordForInsert(zoneID: remote.bookZoneID))
        }

        // Store the remote ID to book pairing which has now been generated
        let booksByRemoteID = booksAndCKRecords.reduce(into: [CKRecord.ID: Book]()) { $0[$1.ckRecord.recordID] = $1.book }

        // Start the upload
        remote.upload(booksAndCKRecords.map { $0.ckRecord }) { [unowned self] error in
            self.context.perform {
                if let error = error, case let ckError = error as? CKError {
                    self.handleError(booksByRemoteID, ckError!)
                }

                for (localBook, ckRecord) in booksAndCKRecords {

                    // If the book was locally deleted in the meantime, we enqueue a remote deletion
                    guard !localBook.isDeleted else {
                        // TODO: Is this necessary? Won't this already have been enqueued?
                        PendingRemoteDeletionItem(context: self.context, ckRecordID: ckRecord.recordID)
                        continue
                    }

                    // Assign the system fields and remote identifier
                    localBook.storeCKRecordSystemFields(ckRecord)
                    localBook.remoteIdentifier = ckRecord.recordID.recordName

                    // Check whether any uploaded fields differ from what is now present in the Book object.
                    // If that is the case, a delta will need to be pushed to CloudKit.
                    let differingKeys = ckRecord.changedBookKeys()
                        .filter { !CKRecord.valuesAreEqual(left: ckRecord[$0], right: $0.value(from: localBook)) }
                    localBook.addPendingRemoteUpdateKeys(differingKeys)
                }

                self.context.saveAndLogIfErrored()
                completion()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate(format: "%K == NULL", #keyPath(Book.remoteIdentifier))
        fetchRequest.fetchBatchSize = 50
        return fetchRequest
    }
}
