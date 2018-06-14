import Foundation
import CoreData
import CloudKit

class BookInserter: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookInserter.self)

    func handleError(_ books: [CKRecordID: Book], _ ckError: CKError) {
        switch ckError.code {
        case .partialFailure:
            let errors = ckError.userInfo[CKPartialErrorsByItemIDKey] as! NSDictionary
            for error in errors {
                handleError(books, error.value as! CKError)
            }
        case .serverRecordChanged:
            let server = ckError.serverRecord
            books[ckError.clientRecord!.recordID]?.updateFrom(ckRecord: server!)
        default: print("Error: \(ckError)")
        }
    }

    var booksBeingProcessed = Set<Book>()

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: BookCloudKitRemote) {

        let booksAndCKRecords = books.filter { !booksBeingProcessed.contains($0) }
            .map { book -> (book: Book, ckRecord: CKRecord) in
                (book, book.CKRecordForInsert(zoneID: remote.bookZoneID))
            }
        booksBeingProcessed.formUnion(books)

        // Store the remote ID to book pairing which has now been generated
        let booksByRemoteID = booksAndCKRecords.reduce(into: [CKRecordID: Book]()) { $0[$1.ckRecord.recordID] = $1.book }

        // Start the upload
        remote.upload(booksAndCKRecords.map { $0.ckRecord }) { [unowned self] error in
            context.perform {
                if let error = error, case let ckError = error as? CKError {
                    self.handleError(booksByRemoteID, ckError!)
                }

                for (localBook, ckRecord) in booksAndCKRecords {

                    // If the book was locally deleted in the meantime, we enqueue a remote deletion
                    guard !localBook.isDeleted else {
                        PendingRemoteDeletionItem(context: context, ckRecordID: ckRecord.recordID)
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
                self.booksBeingProcessed.subtract(books)
                context.saveAndLogIfErrored()
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
