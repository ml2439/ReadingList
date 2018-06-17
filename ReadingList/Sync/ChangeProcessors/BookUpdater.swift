import Foundation
import CoreData
import CloudKit

class BookUpdater: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookUpdater.self)

    func handleItemError(_ ckError: CKError) {
        print("error: \(ckError)")
    }

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: BookCloudKitRemote) {
        let booksAndRecords = books.map { book -> (book: Book, ckRecord: CKRecord, delta: [BookCKRecordKey]) in
            let ckRecord = book.CKRecordForDifferentialUpdate()
            return (book, ckRecord, ckRecord.changedBookKeys())
        }

        remote.upload(booksAndRecords.map { $0.ckRecord }) { [unowned self] error in
            context.perform {
                var failures: [AnyHashable: Error]? = nil
                if let ckError = error as? CKError {
                    //if ckError.code == CKError.Code.networkFailure
                    failures = ckError.partialErrorsByItemID
                }

                for (localBook, ckRecord, delta) in booksAndRecords {
                    guard !localBook.isDeleted else { print("Updated book is now deleted"); continue }

                    // Handle errors
                    if let error = failures?[ckRecord.recordID] {
                        print("Record \(ckRecord.recordID) errored.")
                        self.handleItemError(error as! CKError)
                        continue
                    }

                    // Assign the system fields
                    localBook.storeCKRecordSystemFields(ckRecord)

                    // Remove from the bitmask all fields which were included in the CKRecord we sent to the server,
                    // *and* which still have the same value in the Book which prompted the update.
                    let equalKeys = delta.filter { CKRecord.valuesAreEqual(left: ckRecord[$0], right: $0.value(from: localBook)) }
                    localBook.removePendingRemoteUpdateKeys(equalKeys)
                }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = Book.pendingRemoteUpdatesPredicate
        return fetchRequest
    }
}
