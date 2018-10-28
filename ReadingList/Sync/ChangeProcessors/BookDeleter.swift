import Foundation
import CoreData
import CloudKit
import os.log

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

        os_log("Beginning push of %d delete instructions", type: .info, pendingRemoteDeletes.count)
        remote.remove(pendingRemoteDeletes.map { $0.recordID }) { error in
            self.context.perform {
                os_log("Remote delete complete. Processing results...", type: .info)
                self.processDeletionResults(pendingRemoteDeletes, error: error)
                completion()
            }
        }
    }

    private func processDeletionResults(_ deletionInstructions: [PendingRemoteDeletionItem], error: Error?) {
        let innerErrors: [CKRecord.ID: CKError]?
        if let ckError = error as? CKError {
            switch ckError.code {
            case .batchRequestFailed:
                innerErrors = ckError.innerErrors
            default:
                os_log("Unhandled batch-level error during item deletion: %s", type: .error, ckError.code.name)
                return
            }
        } else {
            innerErrors = nil
            if error != nil {
                os_log("Unexpected error occurred pushing delete instructions", type: .error)
                return
            }
        }

        for deletionInstruction in deletionInstructions {
            if let ckError = innerErrors?[deletionInstruction.recordID] {
                switch ckError.code {
                case .unknownItem:
                    os_log("Remote deletion of record %{public}s failed - the item could not be found. Deleting instruction.", deletionInstruction.recordID.recordName)
                    deletionInstruction.delete()
                case .batchRequestFailed:
                    continue
                default:
                    os_log("Unhandled record-level error during item deletion: %s", type: .error, ckError.code.name)
                }
            } else {
                deletionInstruction.delete()
            }
        }

        let deletedRemoteDeletionItemCount = deletionInstructions.filter { $0.isDeleted }.count
        if deletedRemoteDeletionItemCount != 0 {
            os_log("Deleted %d local remote delete instructions", type: .info, deletedRemoteDeletionItemCount)
            self.context.saveAndLogIfErrored()
        }
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self) as! NSFetchRequest<NSFetchRequestResult>
    }
}
