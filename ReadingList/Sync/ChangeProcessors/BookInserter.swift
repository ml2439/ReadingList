import Foundation
import CoreData

class BookInserter: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookInserter.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: Remote) {

        remote.upload(books) { remoteRecords, error in
            guard let remoteBooks = remoteRecords as? [Book: RemoteBook] else { fatalError("Incorrect type") }
            guard error?.isPermanent != true else { fatalError("do something here") }

            // TODO: Consider whether delayed saves are necessary
            context.perform {
                remoteBooks.forEach { book, remoteBook in
                    book.remoteIdentifier = remoteBook.id
                    book.pendingRemoteUpdate = false
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
