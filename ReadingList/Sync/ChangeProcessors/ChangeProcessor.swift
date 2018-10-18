import Foundation
import CoreData
import CloudKit

protocol DownstreamChangeProcessor: CustomDebugStringConvertible {
    func processRemoteChanges(from zone: CKRecordZone.ID, changes: CKChangeCollection, completion: (() -> Void)?)
}

protocol UpstreamChangeProcessor: CustomDebugStringConvertible {
    func processLocalChanges(_ objects: [NSManagedObject], completion: @escaping () -> Void)
    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> { get }
}

protocol BookUpstreamChangeProcessor: UpstreamChangeProcessor {
    func processLocalChanges(_ books: [Book], completion: @escaping () -> Void)
    var unprocessedChangedBooksRequest: NSFetchRequest<Book> { get }
}

extension BookUpstreamChangeProcessor {

    func processLocalChanges(_ objects: [NSManagedObject], completion: @escaping () -> Void) {
        guard let books = objects as? [Book] else { fatalError("Incorrect object type") }
        print("\(debugDescription) processing \(books.count) objects")
        processLocalChanges(books, completion: completion)
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return unprocessedChangedBooksRequest as! NSFetchRequest<NSFetchRequestResult>
    }
}
