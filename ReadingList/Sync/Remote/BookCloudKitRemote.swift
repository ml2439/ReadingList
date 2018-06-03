import Foundation
import CoreData
import CloudKit

class BookCloudKitRemote: Remote {
    func setupSubscription() {
        let subscription = CKQuerySubscription(recordType: "Mood", predicate: NSPredicate(boolean: true), subscriptionID: "BookDownload",
                                               options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let info = CKNotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        let subscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        subscriptionOperation.modifySubscriptionsCompletionBlock = { (_, _, error: Error?) -> Void in
            if let error = error { print("Failed to modify subscription: \(error)") }
        }
        CKContainer.default().privateCloudDatabase.add(subscriptionOperation)
    }

    func fetchUserID(completion: @escaping (RemoteRecordID?) -> Void) {

    }

    func fetchAllRecords(completion: @escaping ([RemoteRecord]) -> Void) {

    }

    func fetchRecordChanges(completion: @escaping ([RemoteRecordChange], @escaping (Bool) -> Void) -> Void) {

    }

    func upload(_ records: [NSManagedObject], completion: @escaping ([NSManagedObject: RemoteRecord], RemoteError?) -> Void) {

    }

    func update(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void) {

    }

    func remove(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void) {

    }
}
