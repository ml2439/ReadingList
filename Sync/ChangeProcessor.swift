import Foundation
import CoreData

protocol DownstreamChangeProcessor: CustomDebugStringConvertible {
    /**
     
    */
    func processRemoteChanges(_ changes: [RemoteRecordChange], context: NSManagedObjectContext, completion: () -> Void)

    func processAllRemoteRecords(from: Remote, context: NSManagedObjectContext)
}

protocol UpstreamChangeProcessor: CustomDebugStringConvertible {

    /**
     
    */
    func processLocalChanges(_ objects: [NSManagedObject], context: NSManagedObjectContext, remote: Remote)

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> { get }
}
