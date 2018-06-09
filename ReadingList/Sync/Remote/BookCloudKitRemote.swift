import Foundation
import CoreData
import CloudKit

class BookCloudKitRemote: Remote {

    private let bookDownloadSubscriptionID = "BookChanges"
    private let bookCKRecordType = "Book"
    private let bookZoneID = "BookZone"

    private let bookDownloadCKChangeTokenKey = "CK_BookChangesToken"
    private let userRecordNameIDKey = "CK_UserRecordName"

    var userRecordID: String?

    var privateDB: CKDatabase {
        return CKContainer.default().privateCloudDatabase
    }

    func initialise(completion: @escaping () -> Void) {
        if let userRecordName = UserDefaults.standard.string(forKey: userRecordNameIDKey) {
            userRecordID = userRecordName
            createZoneAndSubscription(completion: completion)
        } else {
            CKContainer.default().fetchUserRecordID { ckRecordID, error in
                if let error = error {
                    print("Error \(error)")
                } else {
                    UserDefaults.standard.set(ckRecordID!.recordName, forKey: self.userRecordNameIDKey)
                    self.userRecordID = ckRecordID!.recordName
                    self.createZoneAndSubscription(completion: completion)
                }
            }
        }
    }

    func createZoneAndSubscription(completion: @escaping () -> Void) {
        guard let userRecordID = userRecordID else { fatalError("Missing user record ID") }

        // Create the book zone (TODO: Do not create if already exists?)
        let bookZone = CKRecordZone(zoneID: CKRecordZoneID(zoneName: bookZoneID, ownerName: userRecordID))
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [bookZone], recordZoneIDsToDelete: nil)
        createZoneOperation.modifyRecordZonesCompletionBlock = { zone, zoneID, error in
            print("Zone created")
        }
        privateDB.add(createZoneOperation)

        // Subscribe to changes
        let subscription = CKRecordZoneSubscription(zoneID: bookZone.zoneID, subscriptionID: bookDownloadSubscriptionID)
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

    func fetchRecordChanges(completion: @escaping ([RemoteRecord], [RemoteRecordID]) -> Void) {
        print("Fetching record changes")
        guard let userRecordID = userRecordID else { fatalError("Attempt to fetch all records with uninitialised user record ID") }
        let zoneID = CKRecordZoneID(zoneName: bookZoneID, ownerName: userRecordID)

        var changedRecords = [RemoteRecord]()
        var deletedRecordIDs = [RemoteRecordID]()

        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = UserDefaults.standard.ckServerChangeToken(forKey: bookDownloadCKChangeTokenKey)

        let fetchChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], optionsByRecordZoneID: [zoneID: options])
        fetchChangesOperation.recordZoneChangeTokensUpdatedBlock = { _, changeToken, _ in
            UserDefaults.standard.set(changeToken, forKey: self.bookDownloadCKChangeTokenKey)
        }
        fetchChangesOperation.recordChangedBlock = { changedRecords.append($0) }
        fetchChangesOperation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID.recordName)
        }
        fetchChangesOperation.recordZoneFetchCompletionBlock = { _, changeToken, _, _, error in
            guard error == nil else {
                print("Error: \(error!)")
                return
            }
            UserDefaults.standard.set(changeToken, forKey: self.bookDownloadCKChangeTokenKey)
            completion(changedRecords, deletedRecordIDs)
        }
        privateDB.add(fetchChangesOperation)
    }

    func upload(_ records: [NSManagedObject], completion: @escaping ([RemoteRecord], RemoteError?) -> Void) {
        guard let books = records as? [Book] else { fatalError("wrong type") }
        let newBooks = books.filter({ $0.remoteIdentifier == nil })
        
        
        let operation = CKModifyRecordsOperation(recordsToSave: Array(ckRecords.keys), recordIDsToDelete: nil)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.modifyRecordsCompletionBlock = { modifiedRecords, _, error in
            guard error == nil else { print("Error: \(error!)"); return }
            var results = [NSManagedObject: RemoteRecord]()
            for record in modifiedRecords ?? [] {
                results[ckRecords[record]!] = record
            }
            completion(results, nil)
        }
        CKContainer.default().privateCloudDatabase.add(operation)
    }

    func remove(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void) {
        guard let books = records as? [Book] else { fatalError("wrong type") }
        let ckRecordIDs = books.compactMap { $0.remoteIdentifier }.map { CKRecordID(recordName: $0) }
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ckRecordIDs)
        operation.modifyRecordsCompletionBlock = { _, deletedRecordIDs, error in
            guard error == nil else { print("Error: \(String(describing: error))"); return }
            guard let deletedRecordIDs = deletedRecordIDs else { completion([], nil); return }
            completion(deletedRecordIDs.map { $0.recordName }, nil)
        }
        CKContainer.default().privateCloudDatabase.add(operation)
    }
}
