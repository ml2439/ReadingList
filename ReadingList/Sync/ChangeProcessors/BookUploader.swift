import Foundation
import CoreData
import CloudKit

class BookUploader: BookUpstreamChangeProcessor {

    let debugDescription = String(describing: BookUploader.self)

    func processLocalChanges(_ books: [Book], context: NSManagedObjectContext, remote: BookCloudKitRemote) {
        let ckRecords = books.map { $0.toCKRecord(bookZoneID: remote.bookZoneID) }
        let booksByRemoteID = books.reduce(into: [String: Book]()) { $0[$1.remoteIdentifier!] = $1 }

        remote.upload(ckRecords) { remoteRecords, error in
            guard error == nil else { print("Error: \(error!)"); return }

            // TODO: Consider whether delayed saves are necessary
            context.perform {
                for ckRecord in remoteRecords {
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
            NSPredicate.or([NSPredicate(format: "%K == NULL", #keyPath(Book.remoteIdentifier)),
                            Book.pendingRemoteUpdatesPredicate])
        ])
        return fetchRequest
    }
}
