import Foundation
import CoreData
import CloudKit

class BookDeleter: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookDeleter.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: BookCloudKitRemote) {

        let recordIDs = books.compactMap { $0.getStoredCKRecord()?.recordID }
        remote.remove(recordIDs) { deletedRecordIDs, _ in
            let booksToDelete = books.filter {
                guard let remoteId = $0.remoteIdentifier else { return false }
                return deletedRecordIDs.map { $0.recordName }.contains(remoteId)
            }
            context.perform {
                booksToDelete.forEach { $0.delete() }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            NSPredicate(format: "%K == true", #keyPath(Book.pendingRemoteDeletion)),
            NSPredicate(format: "%K != NULL", #keyPath(Book.remoteIdentifier))
        ])
        return fetchRequest
    }
}
