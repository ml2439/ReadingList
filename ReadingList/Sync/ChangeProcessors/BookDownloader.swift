import Foundation
import CoreData
import CloudKit

class BookDownloader: DownstreamChangeProcessor {

    let debugDescription = String(describing: BookDownloader.self)

    func processRemoteChanges(from zone: CKRecordZoneID, changes: CKChangeCollection,
                              context: NSManagedObjectContext, completion: (() -> Void)?) {
        insertBooks(changes.changedRecords, into: context)
        deleteBooks(with: changes.deletedRecordIDs, in: context)

        // Store the updated change token
        let changeToken = ChangeToken.get(fromContext: context, for: zone) ?? ChangeToken(context: context, zoneID: zone)
        changeToken.changeToken = changes.newChangeToken
        print("Updated change token")

        context.saveAndLogIfErrored()
        completion?()
    }

    private func deleteBooks(with ids: [CKRecordID], in context: NSManagedObjectContext) {
        guard !ids.isEmpty else { return }
        print("\(debugDescription) processing \(ids.count) remote deletions")

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids, in: context)
        booksToDelete.forEach { $0.delete() }
    }

    private func insertBooks(_ remoteBooks: [CKRecord], into context: NSManagedObjectContext) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote insertions")

        let preExistingBooks = locallyPresentBooks(withRemoteIDs: remoteBooks.map { $0.recordID }, in: context)

        for remoteBook in remoteBooks {
            if let localBook = preExistingBooks.first(where: { $0.remoteIdentifier == remoteBook.recordID.recordName }) {
                localBook.updateFrom(ckRecord: remoteBook)
                localBook.remoteIdentifier = remoteBook.recordID.recordName
                localBook.storeCKRecordSystemFields(remoteBook)
            } else {
                let book = Book(context: context, readState: .toRead)
                book.updateFrom(ckRecord: remoteBook)
                book.remoteIdentifier = remoteBook.recordID.recordName
                book.storeCKRecordSystemFields(remoteBook)
            }
        }
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [CKRecordID], in context: NSManagedObjectContext) -> [Book] {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.withRemoteIdentifiers(remoteIDs.map { $0.recordName })
        ])
        return try! context.fetch(fetchRequest)
    }
}
