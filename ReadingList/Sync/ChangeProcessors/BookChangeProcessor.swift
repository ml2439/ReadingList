import Foundation
import CoreData
import CloudKit

protocol BookUpstreamChangeProcessor: UpstreamChangeProcessor {
    func processLocalChanges(_ books: [Book], remote: BookCloudKitRemote, completion: @escaping () -> Void)
    var unprocessedChangedBooksRequest: NSFetchRequest<Book> { get }
}

extension BookUpstreamChangeProcessor {

    func processLocalChanges(_ objects: [NSManagedObject], remote: BookCloudKitRemote, completion: @escaping () -> Void) {
        guard let books = objects as? [Book] else { fatalError("Incorrect object type") }
        print("\(debugDescription) processing \(books.count) objects")
        processLocalChanges(books, remote: remote, completion: completion)
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return unprocessedChangedBooksRequest as! NSFetchRequest<NSFetchRequestResult>
    }
}
