import Foundation
import CoreData
import CloudKit

class BookUpdater: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookUpdater.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: Remote) {

        let booksByRemoteID = books.reduce(into: [String: Book]()) { $0[$1.remoteIdentifier!] = $1 }

        remote.upload(books) { remoteRecords, error in
            guard error?.isPermanent != true else { fatalError("do something here") }
            guard let ckRecords = remoteRecords as? [CKRecord] else { fatalError("Incorrect type") }

            // TODO: Consider whether delayed saves are necessary
            context.perform {
                for ckRecord in ckRecords {
                    guard let book = booksByRemoteID[ckRecord.recordID.recordName] else { fatalError("Missing book") }
                    book.update(from: ckRecord)
                }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.notMarkedForDeletion,
            NSPredicate(format: "%K != NULL", #keyPath(Book.remoteIdentifier)),
            Book.pendingRemoteUpdatesPredicate
        ])
        return fetchRequest
    }
}
