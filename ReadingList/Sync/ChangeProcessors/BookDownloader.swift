import Foundation
import CoreData

class BookDownloader: DownstreamChangeProcessor {

    let debugDescription = String(describing: BookDownloader.self)

    func processAllRemoteRecords(from remote: Remote, context: NSManagedObjectContext) {
        print("Fetching all remote records")

        remote.fetchAllRecords { remoteRecords in
            guard let remoteBooks = remoteRecords as? [RemoteBook] else { fatalError("Wrong type") }

            // Grab any books which exist with the returned remote identifiers; we don't want to re-create them
            let remoteBookIDs = remoteBooks.map { $0.id! }
            let preExistingRemoteIDs = self.locallyPresentBooks(withRemoteIDs: remoteBookIDs, in: context).map { $0.remoteIdentifier! }

            for newRemoteBook in remoteBooks.filter({ !preExistingRemoteIDs.contains($0.id!) }) {
                let book = Book(context: context)
                book.update(from: newRemoteBook)
            }

            context.saveAndLogIfErrored()
        }
    }

    func processRemoteChanges(_ changes: [RemoteRecordChange], context: NSManagedObjectContext, completion: () -> Void) {
        print("Processing \(changes.count) remote changes")

        var createdBooks = [RemoteBook]()
        var updatedBooks = [RemoteBook]()
        var deletionBookIDs = [RemoteRecordID]()
        for change in changes {
            switch change {
            case .insert(let book): createdBooks.append(book as! RemoteBook)
            case .update(let book): updatedBooks.append(book as! RemoteBook)
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

        let booksToDelete = locallyPresentBooks(withRemoteIDs: ids, in: context)
        booksToDelete.forEach { $0.markForDeletion() }
    }

    private func updateBooks(_ remoteBooks: [RemoteBook], in context: NSManagedObjectContext) {
        let booksToUpdate = locallyPresentBooks(from: remoteBooks, in: context)

        for bookToUpdate in booksToUpdate {
            let remoteBook = remoteBooks.first { $0.id! == bookToUpdate.remoteIdentifier! }
            bookToUpdate.update(from: remoteBook!)
        }
    }

    private func insertBooks(_ remoteBooks: [RemoteBook], into context: NSManagedObjectContext) {
        let preExistingBookIDs = locallyPresentBooks(from: remoteBooks, in: context).map { $0.remoteIdentifier! }
        let booksToInsert = remoteBooks.filter { !preExistingBookIDs.contains($0.id!) }

        for bookToInsert in booksToInsert {
            let book = Book(context: context)
            book.update(from: bookToInsert)
        }
    }

    private func locallyPresentBooks(from remoteBooks: [RemoteBook], in context: NSManagedObjectContext) -> [Book] {
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
