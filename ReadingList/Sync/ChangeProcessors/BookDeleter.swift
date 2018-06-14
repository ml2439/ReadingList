import Foundation
import CoreData
import CloudKit

class BookDeleter: UpstreamChangeProcessor {

    let debugDescription = String(describing: BookDeleter.self)

    func processLocalChanges(_ pendingRemoteDeletes: [NSManagedObject], context: NSManagedObjectContext, remote: BookCloudKitRemote) {
        let pendingRemoteDeletes = pendingRemoteDeletes as! [PendingRemoteDeletionItem]

        remote.remove(pendingRemoteDeletes.map { $0.recordID }) { error in
            context.perform {
                guard error == nil else { print(error!); return }
                pendingRemoteDeletes.forEach { $0.delete() }
                context.saveAndLogIfErrored()
            }
        }
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self) as! NSFetchRequest<NSFetchRequestResult>
    }
}
