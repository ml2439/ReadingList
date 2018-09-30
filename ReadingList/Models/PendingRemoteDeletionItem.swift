import Foundation
import CoreData
import CloudKit

@objc(PendingRemoteDeletionItem)
class PendingRemoteDeletionItem: NSManagedObject {
    @NSManaged private var ownerName: String
    @NSManaged private var zoneName: String
    @NSManaged private var recordName: String

    @discardableResult
    convenience init(context: NSManagedObjectContext, ckRecordID: CKRecord.ID) {
        self.init(context: context)
        ownerName = ckRecordID.zoneID.ownerName
        zoneName = ckRecordID.zoneID.zoneName
        recordName = ckRecordID.recordName
    }

    var recordID: CKRecord.ID {
        return CKRecord.ID(recordName: recordName, zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName))
    }
}
