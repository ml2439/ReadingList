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
    var batchSize = 400

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
        var innerErrors: [CKRecord.ID: CKError]?
        if let ckError = error as? CKError {
            os_log("CKError with code %s received", type: .info, ckError.code.name)

            switch ckError.strategy {
            case .disableSync:
                NotificationCenter.default.post(name: NSNotification.Name.DisableCloudSync, object: ckError)
            case .disableSyncUnexpectedError, .resetChangeToken:
                os_log("Unexpected code returned in error response to deletion instruction: %s", type: .fault, ckError.code.name)
                NotificationCenter.default.post(name: NSNotification.Name.DisableCloudSync, object: ckError)
            case .retryLater:
                NotificationCenter.default.post(name: NSNotification.Name.PauseCloudSync, object: ckError)
            case .retrySmallerBatch:
                let newBatchSize = self.batchSize / 2
                os_log("Reducing deletion batch size from %d to %d", self.batchSize, newBatchSize)
                self.batchSize = newBatchSize
            case .handleInnerErrors:
                innerErrors = ckError.innerErrors
            case .handleConcurrencyErrors:
                // This should only happen if there is 1 deletion instruction; otherwise, the batch should have failed
                if deletionInstructions.count == 1 {
                    handleConcurrencyError(ckError, forItem: deletionInstructions[0])
                } else {
                    os_log("Unexpected error code %s occurred when pushing %d delete instructions", type: .error, ckError.code.name, deletionInstructions.count)
                    NotificationCenter.default.post(name: NSNotification.Name.DisableCloudSync, object: ckError)
                }
            }
        } else if let error = error {
            os_log("Unexpected error (non CK) occurred pushing delete instructions: %{public}s", type: .error, error.localizedDescription)
            NotificationCenter.default.post(name: NSNotification.Name.DisableCloudSync, object: error)
        }

        for deletionInstruction in deletionInstructions {
            if let ckError = innerErrors?[deletionInstruction.recordID] {
                handleConcurrencyError(ckError, forItem: deletionInstruction)
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

    private func handleConcurrencyError(_ ckError: CKError, forItem item: PendingRemoteDeletionItem) {
        switch ckError.code {
        case .unknownItem:
            os_log("Remote deletion of record %{public}s failed - the item could not be found. Deleting instruction.", item.recordID.recordName)
            item.delete()
        case .batchRequestFailed:
            return
        default:
            os_log("Unexpected record-level error during item deletion: %s", type: .error, ckError.code.name)
        }
    }

    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self, limit: batchSize) as! NSFetchRequest<NSFetchRequestResult>
    }
}
