import Foundation
import CoreData
import CloudKit

class BookDownloader: DownstreamChangeProcessor {

    init(_ context: NSManagedObjectContext) {
        self.context = context
    }

    let debugDescription = String(describing: BookDownloader.self)
    let context: NSManagedObjectContext

    func processRemoteChanges(from zone: CKRecordZoneID, changes: CKChangeCollection, completion: (() -> Void)?) {
        context.perform {
            self.insertBooks(changes.changedRecords)
            self.deleteBooks(with: changes.deletedRecordIDs)

            // Store the updated change token
            let changeToken = ChangeToken.get(fromContext: self.context, for: zone) ?? ChangeToken(context: self.context, zoneID: zone)
            changeToken.changeToken = changes.newChangeToken
            print("Updated change token")

            self.context.saveAndLogIfErrored()
            completion?()
        }
    }

    private func deleteBooks(with ids: [CKRecordID]) {
        guard !ids.isEmpty else { return }
        print("\(debugDescription) processing \(ids.count) remote deletions")

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids)
        booksToDelete.forEach { $0.delete() }
    }

    private func insertBooks(_ remoteBooks: [CKRecord]) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote insertions")

        let preExistingBooks = locallyPresentBooks(withRemoteIDs: remoteBooks.map { $0.recordID })

        for remoteBook in remoteBooks {
            if let localBook = preExistingBooks.first(where: { $0.remoteIdentifier == remoteBook.recordID.recordName }) {
                localBook.updateFrom(serverRecord: remoteBook)
            } else {
                let book = Book(context: context, readState: .toRead)
                book.updateFrom(serverRecord: remoteBook)
            }
        }
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [CKRecordID]) -> [Book] {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.and([
            Book.withRemoteIdentifiers(remoteIDs.map { $0.recordName })
        ])
        return try! context.fetch(fetchRequest)
    }
}
