import Foundation
import CoreData
import CloudKit

class BookCloudKitRemote {
    let bookZoneName = "BookZone"

    private let userRecordNameKey = "CK_UserRecordName"

    private(set) var userRecordName: String!
    private(set) var bookZoneID: CKRecordZoneID!

    var privateDB: CKDatabase {
        return CKContainer.default().privateCloudDatabase
    }

    var isInitialised: Bool {
        return bookZoneID != nil
    }

    func initialise(completion: @escaping (Error?) -> Void) {
        if let userRecordName = UserDefaults.standard.string(forKey: userRecordNameKey) {
            createZoneAndSubscription(userRecordName: userRecordName, completion: completion)
        } else {
            CKContainer.default().fetchUserRecordID { ckRecordID, error in
                if let error = error {
                    completion(error)
                } else {
                    UserDefaults.standard.set(ckRecordID!.recordName, forKey: self.userRecordNameKey)
                    self.createZoneAndSubscription(userRecordName: ckRecordID!.recordName, completion: completion)
                }
            }
        }
    }

    private func createZoneAndSubscription(userRecordName: String, completion: @escaping (Error?) -> Void) {
        self.userRecordName = userRecordName
        self.bookZoneID = CKRecordZoneID(zoneName: bookZoneName, ownerName: userRecordName)

        // Create the book zone (TODO: Do not create if already exists?)
        let bookZone = CKRecordZone(zoneID: bookZoneID)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [bookZone], recordZoneIDsToDelete: nil)
        createZoneOperation.modifyRecordZonesCompletionBlock = { zone, zoneID, error in
            if let error = error { completion(error) }
        }
        privateDB.add(createZoneOperation)

        // Subscribe to changes
        let subscription = CKRecordZoneSubscription(zoneID: bookZone.zoneID, subscriptionID: "BookChanges")
        subscription.notificationInfo = {
            let info = CKNotificationInfo()
            info.shouldSendContentAvailable = true
            return info
        }()
        let modifySubscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        modifySubscriptionOperation.addDependency(createZoneOperation)
        modifySubscriptionOperation.modifySubscriptionsCompletionBlock = { _, _, error in
            if let error = error {
                completion(error)
            } else {
                print("Subscription modified")
                completion(nil)
            }
        }
        privateDB.add(modifySubscriptionOperation)
    }

    func fetchRecordChanges(changeToken: CKServerChangeToken?, completion: @escaping (CKChangeCollection) -> Void) {
        print("Fetching record changes")

        var changedRecords = [CKRecord]()
        var deletedRecordIDs = [CKRecordID]()

        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [bookZoneID], optionsByRecordZoneID: [bookZoneID: options])
        operation.qualityOfService = .userInitiated
        operation.recordChangedBlock = { changedRecords.append($0) }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }
        operation.recordZoneChangeTokensUpdatedBlock = { _, changeToken, _ in
            print("change token block ran \(changeToken)")
        }
        operation.recordZoneFetchCompletionBlock = { _, changeToken, _, _, error in
            guard error == nil else {
                print("Error: \(error!)")
                return
            }
            guard let changeToken = changeToken else { fatalError("Unexpectedly missing change token") }
            let changes = CKChangeCollection(changedRecords: changedRecords, deletedRecordIDs: deletedRecordIDs, newChangeToken: changeToken)
            completion(changes)
        }
        privateDB.add(operation)
    }

    func upload(_ records: [CKRecord], completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsCompletionBlock = { _, _, error in
            completion(error)
        }
        CKContainer.default().privateCloudDatabase.add(operation)
    }

    func remove(_ recordIDs: [CKRecordID], completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsCompletionBlock = { _, _, error in
            completion(error)
        }
        CKContainer.default().privateCloudDatabase.add(operation)
    }
}

class CKChangeCollection {
    let changedRecords: [CKRecord]
    let deletedRecordIDs: [CKRecordID]
    let newChangeToken: CKServerChangeToken

    init(changedRecords: [CKRecord], deletedRecordIDs: [CKRecordID], newChangeToken: CKServerChangeToken) {
        self.changedRecords = changedRecords
        self.deletedRecordIDs = deletedRecordIDs
        self.newChangeToken = newChangeToken
    }

    var isEmpty: Bool {
        return changedRecords.isEmpty && deletedRecordIDs.isEmpty
    }
}
