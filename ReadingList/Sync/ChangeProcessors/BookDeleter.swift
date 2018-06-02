import Foundation
import CoreData

class BookDeleter: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookDeleter.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: Remote) {
        remote.remove(books) { deletedRecordIDs, error in
            let deletions = books.filter {
                guard let remoteId = $0.remoteIdentifier else { return false }
                return deletedRecordIDs.contains(remoteId)
            }
            context.perform {
                deletions.forEach {
                    $0.delete()
                }
                if case .permanent(let perminantErroredIDs)? = error {
                    books.filter { perminantErroredIDs.contains($0.remoteIdentifier!) }.forEach {
                        $0.delete()
                    }
                }
                context.saveAndLogIfErrored()
            }
        }
    }

    let unprocessedChangedBooksRequest: NSFetchRequest<Book> = {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            NSPredicate(format: "%K == true", #keyPath(Book.pendingRemoteDeletion)),
            NSPredicate(format: "%K != NULL", #keyPath(Book.remoteIdentifier))
        ])
        return fetchRequest
    }()
}
