import Foundation
import CoreData
import CloudKit

class BookDownloader: DownstreamChangeProcessor {

    let debugDescription = String(describing: BookDownloader.self)

    func processRemoteChanges(from zone: CKRecordZoneID, changedRecords: [CKRecord], deletedRecordIDs: [CKRecordID],
                              newChangeToken: CKServerChangeToken, context: NSManagedObjectContext, completion: (() -> Void)? = nil) {
        print("\(debugDescription) processing \(changedRecords.count) remote changes and \(deletedRecordIDs.count) remote deletions.")

        insertBooks(changedRecords, into: context)
        deleteBooks(with: deletedRecordIDs, in: context)

        // Store the updated change token
        let changeToken = ChangeToken.get(fromContext: context, for: zone) ?? ChangeToken(context: context, zoneID: zone)
        changeToken.changeToken = NSKeyedArchiver.archivedData(withRootObject: newChangeToken)

        context.saveAndLogIfErrored()
        completion?()
    }

    private func deleteBooks(with ids: [CKRecordID], in context: NSManagedObjectContext) {
        guard !ids.isEmpty else { return }
        print("\(debugDescription) processing \(ids.count) remote deletions")

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids, in: context)
        booksToDelete.forEach { $0.markForDeletion() }
    }

    private func insertBooks(_ remoteBooks: [CKRecord], into context: NSManagedObjectContext) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote insertions")

        let preExistingBooks = locallyPresentBooks(withRemoteIDs: remoteBooks.map { $0.recordID }, in: context)

        for remoteBook in remoteBooks {
            if let localBook = preExistingBooks.first(where: { $0.remoteIdentifier == remoteBook.recordID.recordName }) {
                localBook.update(from: remoteBook)
            } else {
                let book = Book(context: context, readState: .toRead)
                book.update(from: remoteBook)
            }
        }
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [CKRecordID], in context: NSManagedObjectContext) -> [Book] {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.withRemoteIdentifiers(remoteIDs.map { $0.recordName }),
            Book.notMarkedForDeletion
        ])
        return try! context.fetch(fetchRequest)
    }
}
