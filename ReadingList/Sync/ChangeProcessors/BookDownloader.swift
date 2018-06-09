import Foundation
import CoreData
import CloudKit

class BookDownloader: DownstreamChangeProcessor {

    let debugDescription = String(describing: BookDownloader.self)

    func processRemoteChanges(changedRecords: [RemoteRecord], deletedRecordIDs: [RemoteRecordID], context: NSManagedObjectContext, completion: () -> Void) {
        print("\(debugDescription) processing \(changedRecords.count) remote changes and \(deletedRecordIDs.count) remote deletions.")

        insertBooks(changedRecords, into: context)
        deleteBooks(with: deletedRecordIDs, in: context)

        context.saveAndLogIfErrored()
        completion()
    }

    private func deleteBooks(with ids: [RemoteRecordID], in context: NSManagedObjectContext) {
        guard !ids.isEmpty else { return }
        print("\(debugDescription) processing \(ids.count) remote deletions")

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids, in: context)
        booksToDelete.forEach { $0.markForDeletion() }
    }

    private func insertBooks(_ remoteBooks: [RemoteRecord], into context: NSManagedObjectContext) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote insertions")

        let preExistingBooks = locallyPresentBooks(withRemoteIDs: remoteBooks.map { $0.id! }, in: context)

        for remoteBook in remoteBooks {
            if let localBook = preExistingBooks.first(where: { $0.remoteIdentifier == remoteBook.id }) {
                localBook.update(from: remoteBook as! CKRecord)
            } else {
                let book = Book(context: context)
                book.update(from: remoteBook as! CKRecord)
            }
        }
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [RemoteRecordID], in context: NSManagedObjectContext) -> [Book] {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.withRemoteIdentifiers(remoteIDs),
            Book.notMarkedForDeletion
        ])
        return try! context.fetch(fetchRequest)
    }
}
