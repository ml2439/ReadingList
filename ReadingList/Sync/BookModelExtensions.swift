import Foundation
import CoreData

extension Book {
    @NSManaged var remoteIdentifier: RemoteRecordID?

    // Pending remote deletion flag should never get un-done. Hence, it cannot be set publicly, and can
    // only be set to "true" via a public function.
    @NSManaged private(set) var pendingRemoteDeletion: Bool
    func markForDeletion() { pendingRemoteDeletion = true }

    @NSManaged var pendingRemoteUpdate: Bool

    static var notMarkedForDeletion: NSPredicate {
        return NSPredicate(format: "%K == false", #keyPath(Book.pendingRemoteDeletion))
    }

    static func withRemoteIdentifiers(_ ids: [RemoteRecordID]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }

    func update(from remote: RemoteBook) {
        self.googleBooksId = remote.googleBooksId
        self.remoteIdentifier = remote.id
    }
}
