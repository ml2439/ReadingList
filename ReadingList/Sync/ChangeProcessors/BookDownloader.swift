import Foundation
import CoreData
import CloudKit
import os.log

class BookDownloader: DownstreamChangeProcessor {

    init(_ context: NSManagedObjectContext) {
        self.context = context
    }

    let debugDescription = String(describing: BookDownloader.self)
    let context: NSManagedObjectContext

    func processRemoteChanges(from zone: CKRecordZone.ID, changes: CKChangeCollection, completion: (() -> Void)?) {
        context.perform {
            os_log("%d records and %d remote deletions received", type: .info, changes.changedRecords.count, changes.deletedRecordIDs.count)
            self.downloadBooks(changes.changedRecords)
            self.deleteBooks(with: changes.deletedRecordIDs)

            // Store the updated change token
            let changeTokenToPersist: ChangeToken
            if let changeToken = ChangeToken.get(fromContext: self.context, for: zone) {
                os_log("Updating existing persisted change token", type: .info)
                changeTokenToPersist = changeToken
            } else {
                os_log("No existing persisted change token exists - creating one", type: .info)
                changeTokenToPersist = ChangeToken(context: self.context, zoneID: zone)
            }
            changeTokenToPersist.changeToken = changes.newChangeToken

            self.context.saveAndLogIfErrored()
            completion?()
        }
    }

    private func deleteBooks(with ids: [CKRecord.ID]) {
        guard !ids.isEmpty else { return }
        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids)
        os_log("Deleting %d found local books", type: .info, booksToDelete.count)

        booksToDelete.forEach { $0.delete() }
    }

    private func downloadBooks(_ remoteBooks: [CKRecord]) {
        guard !remoteBooks.isEmpty else { return }

        for remoteBook in remoteBooks {
            if let localBook = lookupLocalBook(for: remoteBook) {
                os_log("Updating existing local book with remote record %{public}s", type: .info, remoteBook.recordID.recordName)
                localBook.update(from: remoteBook)
            } else {
                os_log("Creating new book from remote record %{public}s", type: .info, remoteBook.recordID.recordName)
                let book = Book(context: context, readState: .toRead)
                book.update(from: remoteBook)
            }
        }
    }

    private func lookupLocalBook(for remoteBook: CKRecord) -> Book? {
        let remoteIdLookup = NSManagedObject.fetchRequest(Book.self)
        remoteIdLookup.predicate = Book.withRemoteIdentifier(remoteBook.recordID.recordName)
        remoteIdLookup.fetchLimit = 1
        if let book = (try! context.fetch(remoteIdLookup)).first {
            os_log("Found local book with specified remote identifier %{public}s", type: .debug, remoteBook.recordID.recordName)
            return book
        }

        let localIdLookup = NSManagedObject.fetchRequest(Book.self)
        localIdLookup.fetchLimit = 1
        localIdLookup.predicate = Book.candidateBookForRemoteIdentifier(remoteBook.recordID)
        if let book = (try! context.fetch(localIdLookup)).first {
            os_log("Found candidate local book corresponding to remote identifier %{public}s", type: .debug, remoteBook.recordID.recordName)
            return book
        }

        return nil
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [CKRecord.ID]) -> [Book] {
        os_log("Fetching up to %d local books corresponding to supplied remote identifiers", type: .debug, remoteIDs.count)
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = Book.withRemoteIdentifiers(remoteIDs.map { $0.recordName })
        return try! context.fetch(fetchRequest)
    }
}
