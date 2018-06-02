import Foundation
import CoreData

class BookUpdater: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookUpdater.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: Remote) {

        remote.update(books) { remoteRecordIDs, error in
            // TODO: This doesn't use the dispatchGroup. Hmm. Wrap it in another object? Or pass in the SyncCoordinator?
            context.perform {
                guard error?.isPermanent != true else { fatalError("do something here") }
                for book in books {
                    if remoteRecordIDs.contains(where: { book.remoteIdentifier == $0 }) {
                        book.pendingRemoteUpdate = false
                    }
                }
                context.saveAndLogIfErrored()
                //context.delayedSaveOrRollback()
            }
        }
    }

    let unprocessedChangedBooksRequest: NSFetchRequest<Book> = {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.notMarkedForDeletion,
            NSPredicate(format: "%K != NULL", #keyPath(Book.remoteIdentifier)),
            NSPredicate(format: "%K == true", #keyPath(Book.pendingRemoteUpdate))
        ])
        return fetchRequest
    }()
}
