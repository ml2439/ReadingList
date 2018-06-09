import Foundation
import CoreData
import CloudKit

class BookInserter: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookInserter.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: Remote) {

        // Generate a remote identifier for each book, so that we can determine which returned CKRecord
        // belongs to which Book after the upload.
        var booksByRemoteID = [String: Book]()
        for book in books {
            let remoteID = "Book.\(UUID().uuidString)"
            book.remoteIdentifier = remoteID
            booksByRemoteID[remoteID] = book
        }

        remote.upload(books) { remoteRecords, error in
            guard let remoteBooks = remoteRecords as? [CKRecord] else { fatalError("Incorrect type") }
            guard error?.isPermanent != true else { fatalError("do something here") }

            // TODO: Consider whether delayed saves are necessary
            context.perform {
                for ckRecord in remoteBooks {
                    guard let localBook = booksByRemoteID[ckRecord.recordID.recordName] else { print("Mismatch of IDs."); continue }

                    // Assign the system fields and update the present values
                    localBook.update(from: ckRecord)
                }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.notMarkedForDeletion,
            NSPredicate(format: "%K == NULL", #keyPath(Book.remoteIdentifier))
        ])
        return fetchRequest
    }
}
