import Foundation
import CoreData
import CloudKit

protocol UpstreamChangeProcessor: CustomDebugStringConvertible {
    var batchSize: Int { get set }
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
        processLocalChanges(books, completion: completion)
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return unprocessedChangedBooksRequest as! NSFetchRequest<NSFetchRequestResult>
    }
}
