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
            self.downloadBooks(changes.changedRecords)
            self.deleteBooks(with: changes.deletedRecordIDs)

            // Store the updated change token
            let changeToken = ChangeToken.get(fromContext: self.context, for: zone) ?? ChangeToken(context: self.context, zoneID: zone)
            changeToken.changeToken = changes.newChangeToken
            print("Updated change token")

            self.context.saveAndLogIfErrored()
            completion?()
        }
    }

    private func deleteBooks(with ids: [CKRecord.ID]) {
        guard !ids.isEmpty else { return }
        print("\(debugDescription) processing \(ids.count) remote deletions")

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids)
        booksToDelete.forEach { $0.delete() }
    }

    private func downloadBooks(_ remoteBooks: [CKRecord]) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote insertions")

        for remoteBook in remoteBooks {
            if let localBook = lookupLocalBook(for: remoteBook) {
                localBook.updateFrom(serverRecord: remoteBook)
            } else {
                let book = Book(context: context, readState: .toRead)
                book.updateFrom(serverRecord: remoteBook)
            }
        }
    }

    private func lookupLocalBook(for remoteBook: CKRecord) -> Book? {
        let remoteIdLookup = NSManagedObject.fetchRequest(Book.self)
        remoteIdLookup.predicate = Book.withRemoteIdentifier(remoteBook.recordID.recordName)
        remoteIdLookup.fetchLimit = 1
        if let book = (try! context.fetch(remoteIdLookup)).first { return book }

        if let remoteGoogleBooksId = remoteBook[BookCKRecordKey.googleBooksId] as? String {
            let googleIdLookup = NSManagedObject.fetchRequest(Book.self)
            googleIdLookup.predicate = NSPredicate(format: "%K == %@", #keyPath(Book.googleBooksId), remoteGoogleBooksId)
            googleIdLookup.fetchLimit = 1
            if let book = (try! context.fetch(googleIdLookup)).first { return book }
        }

        if let remoteIsbn = remoteBook[BookCKRecordKey.isbn13] as? String {
            let isbnLookup = NSManagedObject.fetchRequest(Book.self)
            isbnLookup.predicate = NSPredicate(format: "%K == %@", #keyPath(Book.isbn13), remoteIsbn)
            isbnLookup.fetchLimit = 1
            if let book = (try! context.fetch(isbnLookup)).first { return book }
        }

        return nil
    }

    private func locallyPresentBooks(withRemoteIDs remoteIDs: [CKRecord.ID]) -> [Book] {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = Book.withRemoteIdentifiers(remoteIDs.map { $0.recordName })
        return try! context.fetch(fetchRequest)
    }
}
