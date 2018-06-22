import Foundation
import CoreData
import CloudKit

protocol DownstreamChangeProcessor: CustomDebugStringConvertible {
    func processRemoteChanges(from zone: CKRecordZoneID, changes: CKChangeCollection, completion: (() -> Void)?)
}

protocol UpstreamChangeProcessor: CustomDebugStringConvertible {
    func processLocalChanges(_ objects: [NSManagedObject], remote: BookCloudKitRemote)
    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> { get }
}
