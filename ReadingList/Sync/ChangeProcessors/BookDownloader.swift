import Foundation
import CoreData

class BookDownloader: DownstreamChangeProcessor {

    let debugDescription = String(describing: BookDownloader.self)

    func processAllRemoteRecords(from remote: Remote, context: NSManagedObjectContext) {
        print("\(debugDescription) processing all remote records")

        remote.fetchAllRecords { remoteRecords in

            // Grab any books which exist with the returned remote identifiers; we don't want to re-create them
            let remoteBookIDs = remoteRecords.map { $0.id! }
            let preExistingRemoteIDs = self.locallyPresentBooks(withRemoteIDs: remoteBookIDs, in: context).map { $0.remoteIdentifier! }

            for newRemoteBook in remoteRecords.filter({ !preExistingRemoteIDs.contains($0.id!) }) {
                let book = Book(context: context)
                book.update(from: newRemoteBook)
            }

            context.saveAndLogIfErrored()
        }
    }

    func processRemoteChanges(_ changes: [RemoteRecordChange], context: NSManagedObjectContext, completion: () -> Void) {
        print("\(debugDescription) processing \(changes.count) remote changes")

        var createdBooks = [RemoteRecord]()
        var updatedBooks = [RemoteRecord]()
        var deletionBookIDs = [RemoteRecordID]()
        for change in changes {
            switch change {
            case .insert(let book): createdBooks.append(book)
            case .update(let book): updatedBooks.append(book)
            case .delete(let id): deletionBookIDs.append(id)
            }
        }

        insertBooks(createdBooks, into: context)
        updateBooks(updatedBooks, in: context)
        deleteBooks(with: deletionBookIDs, in: context)

        context.saveAndLogIfErrored()
        completion()
    }

    private func deleteBooks(with ids: [RemoteRecordID], in context: NSManagedObjectContext) {
        guard !ids.isEmpty else { return }
        print("\(debugDescription) processing \(ids.count) remote deletions")

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids, in: context)
        booksToDelete.forEach { $0.markForDeletion() }
    }

    private func updateBooks(_ remoteBooks: [RemoteRecord], in context: NSManagedObjectContext) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote updates")

        for bookToUpdate in locallyPresentBooks(from: remoteBooks, in: context) {
            let remoteBook = remoteBooks.first { $0.id! == bookToUpdate.remoteIdentifier! }
            bookToUpdate.update(from: remoteBook!)
        }
    }

    private func insertBooks(_ remoteBooks: [RemoteRecord], into context: NSManagedObjectContext) {
        guard !remoteBooks.isEmpty else { return }
        print("\(debugDescription) processing \(remoteBooks.count) remote insertions")

        let preExistingBookIDs = locallyPresentBooks(from: remoteBooks, in: context).map { $0.remoteIdentifier! }
        remoteBooks.filter { !preExistingBookIDs.contains($0.id!) }.forEach {
            let book = Book(context: context)
            book.update(from: $0)
        }
    }

    private func locallyPresentBooks(from remoteBooks: [RemoteRecord], in context: NSManagedObjectContext) -> [Book] {
        return locallyPresentBooks(withRemoteIDs: remoteBooks.map { $0.id! }, in: context)
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
