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

    func initialise(completion: @escaping () -> Void) {
        if let userRecordName = UserDefaults.standard.string(forKey: userRecordNameKey) {
            createZoneAndSubscription(userRecordName: userRecordName, completion: completion)
        } else {
            CKContainer.default().fetchUserRecordID { ckRecordID, error in
                if let error = error {
                    print("Error \(error)")
                } else {
                    UserDefaults.standard.set(ckRecordID!.recordName, forKey: self.userRecordNameKey)
                    self.createZoneAndSubscription(userRecordName: ckRecordID!.recordName, completion: completion)
                }
            }
        }
    }

    private func createZoneAndSubscription(userRecordName: String, completion: @escaping () -> Void) {
        self.userRecordName = userRecordName
        self.bookZoneID = CKRecordZoneID(zoneName: bookZoneName, ownerName: userRecordName)

        // Create the book zone (TODO: Do not create if already exists?)
        let bookZone = CKRecordZone(zoneID: bookZoneID)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [bookZone], recordZoneIDsToDelete: nil)
        createZoneOperation.modifyRecordZonesCompletionBlock = { zone, zoneID, error in
            print("Zone created")
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
            guard error == nil else {
                print("Error: \(error!)")
                return
            }
            print("Subscription modified")
            completion()
        }
        privateDB.add(modifySubscriptionOperation)
    }

    func fetchRecordChanges(changeToken: CKServerChangeToken?, completion: @escaping (CKChangeCollection) -> Void) {
        print("Fetching record changes")

        var changedRecords = [CKRecord]()
        var deletedRecordIDs = [CKRecordID]()

        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = changeToken

        let fetchChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [bookZoneID], optionsByRecordZoneID: [bookZoneID: options])
        fetchChangesOperation.recordChangedBlock = { changedRecords.append($0) }
        fetchChangesOperation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }
        fetchChangesOperation.recordZoneFetchCompletionBlock = { _, changeToken, _, _, error in
            guard error == nil else {
                print("Error: \(error!)")
                return
            }
            let changes = CKChangeCollection(changedRecords: changedRecords, deletedRecordIDs: deletedRecordIDs, newChangeToken: changeToken!)
            completion(changes)
        }
        privateDB.add(fetchChangesOperation)
    }

    func upload(_ records: [CKRecord], completion: @escaping ([CKRecord], Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.modifyRecordsCompletionBlock = { modifiedRecords, _, error in
            guard error == nil else { print("Error: \(error!)"); return }
            completion(modifiedRecords ?? [], nil)
        }
        CKContainer.default().privateCloudDatabase.add(operation)
    }

    func remove(_ recordIDs: [CKRecordID], completion: @escaping ([CKRecordID], Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.modifyRecordsCompletionBlock = { _, deletedRecordIDs, error in
            guard error == nil else { print("Error: \(String(describing: error))"); return }
            completion(deletedRecordIDs ?? [], nil)
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
