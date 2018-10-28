import Foundation
import CoreData
import CloudKit
import os.log

class BookCloudKitRemote {
    let bookZoneName = "BookZone"

    private let userRecordNameKey = "CK_UserRecordName"

    private(set) var userRecordName: String!
    private(set) var bookZoneID: CKRecordZone.ID!

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
        self.bookZoneID = CKRecordZone.ID(zoneName: bookZoneName, ownerName: userRecordName)

        // Ensure the book zone exists. We're not calling the error callback here, since the subsequent operation is
        // not cancelled if this one fails. If the zone fails to get created, then the second operation will fail too.
        let bookZone = CKRecordZone(zoneID: bookZoneID)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [bookZone], recordZoneIDsToDelete: nil)
        createZoneOperation.modifyRecordZonesCompletionBlock = { _, _, error in
            if let error = error {
                os_log("Book record zone creation failed: %{public}s", type: .error, error.localizedDescription)
            } else {
                os_log("Record zone created", type: .info)
            }
        }
        createZoneOperation.qualityOfService = .userInitiated
        privateDB.add(createZoneOperation)

        // Create a subscribe and to it
        let subscription = CKRecordZoneSubscription(zoneID: bookZone.zoneID, subscriptionID: "BookChanges")
        subscription.notificationInfo = CKSubscription.NotificationInfo(shouldSendContentAvailable: true)

        let modifySubscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        modifySubscriptionOperation.addDependency(createZoneOperation)
        modifySubscriptionOperation.qualityOfService = .userInitiated
        modifySubscriptionOperation.modifySubscriptionsCompletionBlock = { _, _, error in
            if let error = error {
                os_log("Book record zone subscription creation failed: %{public}s", type: .error, error.localizedDescription)
                completion(error)
            } else {
                os_log("Record zone subscription created", type: .info)
                completion(nil)
            }
        }
        privateDB.add(modifySubscriptionOperation)
    }

    func fetchRecordChanges(changeToken: CKServerChangeToken?, completion: @escaping (Error?, CKChangeCollection?) -> Void) {
        if changeToken == nil {
            os_log("Fetching all records", type: .info)
        } else {
            os_log("Fetching record changes using change token", type: .info)
        }

        var changedRecords = [CKRecord]()
        var deletedRecordIDs = [CKRecord.ID]()

        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
        options.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [bookZoneID], optionsByRecordZoneID: [bookZoneID: options])
        operation.qualityOfService = .userInitiated
        operation.recordChangedBlock = { changedRecords.append($0) }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }
        operation.recordZoneChangeTokensUpdatedBlock = { _, changeToken, _ in
            os_log("Change token reported updated", type: .debug)
        }
        operation.recordZoneFetchCompletionBlock = { _, changeToken, _, _, error in
            os_log("Record fetch batch operation complete", type: .info)
            if let error = error {
                completion(error, nil)
                return
            }
            guard let changeToken = changeToken else { fatalError("Unexpectedly missing change token") }
            let changes = CKChangeCollection(changedRecords: changedRecords, deletedRecordIDs: deletedRecordIDs, newChangeToken: changeToken)
            completion(nil, changes)
        }
        operation.completionBlock = {
            os_log("Record fetch operation complete", type: .info)
        }
        privateDB.add(operation)
    }

    func upload(_ records: [CKRecord], completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsCompletionBlock = { _, _, error in
            completion(error)
        }
        CKContainer.default().privateCloudDatabase.add(operation)
    }

    func remove(_ recordIDs: [CKRecord.ID], completion: @escaping (Error?) -> Void) {
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
    let deletedRecordIDs: [CKRecord.ID]
    let newChangeToken: CKServerChangeToken

    init(changedRecords: [CKRecord], deletedRecordIDs: [CKRecord.ID], newChangeToken: CKServerChangeToken) {
        self.changedRecords = changedRecords
        self.deletedRecordIDs = deletedRecordIDs
        self.newChangeToken = newChangeToken
    }

    var isEmpty: Bool {
        return changedRecords.isEmpty && deletedRecordIDs.isEmpty
    }
}
