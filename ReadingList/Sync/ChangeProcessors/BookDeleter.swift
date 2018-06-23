import Foundation
import CoreData
import CloudKit

class BookDeleter: UpstreamChangeProcessor {

    init(_ context: NSManagedObjectContext) {
        self.context = context
    }

    let debugDescription = String(describing: BookDeleter.self)
    let context: NSManagedObjectContext

    func processLocalChanges(_ pendingRemoteDeletes: [NSManagedObject], remote: BookCloudKitRemote, completion: @escaping () -> Void) {
        let pendingRemoteDeletes = pendingRemoteDeletes as! [PendingRemoteDeletionItem]

        remote.remove(pendingRemoteDeletes.map { $0.recordID }) { error in
            self.context.perform {
                guard error == nil else { print(error!); return }
                pendingRemoteDeletes.forEach { $0.delete() }
                self.context.saveAndLogIfErrored()

                completion()
            }
        }
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self) as! NSFetchRequest<NSFetchRequestResult>
    }
}
