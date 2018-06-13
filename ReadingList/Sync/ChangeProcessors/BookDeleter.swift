import Foundation
import CoreData
import CloudKit

class BookDeleter: UpstreamChangeProcessor {

    let debugDescription = String(describing: BookDeleter.self)

    func processLocalChanges(_ pendingRemoteDeletes: [NSManagedObject], context: NSManagedObjectContext, remote: BookCloudKitRemote) {
        let pendingRemoteDeletes = pendingRemoteDeletes as! [PendingRemoteDeletionItem]

        remote.remove(pendingRemoteDeletes.map { $0.recordID }) { deletedRecordIDs, _ in
            context.perform {
                pendingRemoteDeletes.filter { deletedRecordIDs!.contains($0.recordID) }.forEach { $0.delete() }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self) as! NSFetchRequest<NSFetchRequestResult>
    }
}
