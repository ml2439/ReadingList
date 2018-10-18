import Foundation
import CoreData
import CloudKit

class BookDeleter: UpstreamChangeProcessor {

    init(_ context: NSManagedObjectContext, _ remote: BookCloudKitRemote) {
        self.context = context
        self.remote = remote
    }

    let debugDescription = String(describing: BookDeleter.self)
    let context: NSManagedObjectContext
    let remote: BookCloudKitRemote

    func processLocalChanges(_ pendingRemoteDeletes: [NSManagedObject], completion: @escaping () -> Void) {
        let pendingRemoteDeletes = pendingRemoteDeletes as! [PendingRemoteDeletionItem]

        print("Beginning push of \(pendingRemoteDeletes.count) delete instructions.")
        remote.remove(pendingRemoteDeletes.map { $0.recordID }) { error in
            self.context.perform {
                print("Remote delete complete. Processing results...")
                if let error = error {
                    print(error)
                    // TODO: grab inner errors if present, use them to delete the deletion token of any already remotely-deleted book
                    return
                }

                for pendingDelete in pendingRemoteDeletes {
                    pendingDelete.delete()
                }
                self.context.saveAndLogIfErrored()
                completion()
            }
        }
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self) as! NSFetchRequest<NSFetchRequestResult>
    }
}
