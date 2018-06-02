import Foundation
import CoreData

class BookUpdater: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookUpdater.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: Remote) {

        remote.update(books) { remoteRecordIDs, error in
            // TODO: Consider whether delayed saves are necessary
            context.perform {
                guard error?.isPermanent != true else { fatalError("do something here") }
                for book in books {
                    if remoteRecordIDs.contains(where: { book.remoteIdentifier == $0 }) {
                        book.pendingRemoteUpdate = false
                    }
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
            NSPredicate(format: "%K == true", #keyPath(Book.pendingRemoteUpdate))
        ])
        return fetchRequest
    }
}
