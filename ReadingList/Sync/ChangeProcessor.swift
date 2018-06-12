import Foundation
import CoreData
import CloudKit

protocol DownstreamChangeProcessor: CustomDebugStringConvertible {
    func processRemoteChanges(from zone: CKRecordZoneID, changes: CKChangeCollection, context: NSManagedObjectContext, completion: (() -> Void)?)
}

protocol UpstreamChangeProcessor: CustomDebugStringConvertible {
    func processLocalChanges(_ objects: [NSManagedObject], context: NSManagedObjectContext, remote: BookCloudKitRemote)
    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> { get }
}
