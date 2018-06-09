import Foundation
import CoreData

protocol DownstreamChangeProcessor: CustomDebugStringConvertible {
    func processRemoteChanges(changedRecords: [RemoteRecord], deletedRecordIDs: [RemoteRecordID], context: NSManagedObjectContext, completion: () -> Void)
}

protocol UpstreamChangeProcessor: CustomDebugStringConvertible {
    func processLocalChanges(_ objects: [NSManagedObject], context: NSManagedObjectContext, remote: Remote)
    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> { get }
}
