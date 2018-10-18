import Foundation
import CoreData
import CloudKit

class BookDownloader: DownstreamChangeProcessor {

    init(_ context: NSManagedObjectContext) {
        self.context = context
    }

    let debugDescription = String(describing: BookDownloader.self)
    let context: NSManagedObjectContext

    func processRemoteChanges(from zone: CKRecordZone.ID, changes: CKChangeCollection, completion: (() -> Void)?) {
        context.perform {
            print("\(changes.changedRecords.count + changes.deletedRecordIDs.count) remote changes received")
            self.downloadBooks(changes.changedRecords)
            self.deleteBooks(with: changes.deletedRecordIDs)

            // Store the updated change token
            let changeToken = ChangeToken.get(fromContext: self.context, for: zone) ?? ChangeToken(context: self.context, zoneID: zone)
            changeToken.changeToken = changes.newChangeToken
            print("Updated change token to \(changes.newChangeToken)")

            self.context.saveAndLogIfErrored()
            completion?()
        }
    }

    private func deleteBooks(with ids: [CKRecord.ID]) {
        guard !ids.isEmpty else { return }
        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids)
        print("\(debugDescription) processing \(ids.count) remote deletions (\(booksToDelete.count) present)")

        booksToDelete.forEach { $0.delete() }
    }

    private func downloadBooks(_ remoteBooks: [CKRecord]) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote modification")

        for remoteBook in remoteBooks {
            if let localBook = lookupLocalBook(for: remoteBook) {
                localBook.update(from: remoteBook)
            } else {
                let book = Book(context: context, readState: .toRead)
                book.update(from: remoteBook)
            }
        }
    }

    private func lookupLocalBook(for remoteBook: CKRecord) -> Book? {
        let remoteIdLookup = NSManagedObject.fetchRequest(Book.self)
        remoteIdLookup.predicate = Book.withRemoteIdentifier(remoteBook.recordID.recordName)
        remoteIdLookup.fetchLimit = 1
        if let book = (try! context.fetch(remoteIdLookup)).first { return book }

        let localIdLookup = NSManagedObject.fetchRequest(Book.self)
        localIdLookup.fetchLimit = 1
        localIdLookup.predicate = Book.candidateBookForRemoteIdentifier(remoteBook.recordID)
        if let book = (try! context.fetch(localIdLookup)).first { return book }
        return nil
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [CKRecord.ID]) -> [Book] {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = Book.withRemoteIdentifiers(remoteIDs.map { $0.recordName })
        return try! context.fetch(fetchRequest)
    }
}
