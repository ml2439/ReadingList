import Foundation
import CoreData
import CloudKit

@objc(ChangeToken)
public class ChangeToken: NSManagedObject {
    @NSManaged private(set) var ownerName: String
    @NSManaged private(set) var zoneName: String
    @NSManaged var changeToken: Data

    convenience init(context: NSManagedObjectContext, zoneID: CKRecordZoneID) {
        self.init(context: context)
        self.ownerName = zoneID.ownerName
        self.zoneName = zoneID.zoneName
    }

    static func get(fromContext context: NSManagedObjectContext, for zoneID: CKRecordZoneID) -> ChangeToken? {
        let fetchRequest = NSManagedObject.fetchRequest(ChangeToken.self, limit: 1, batch: 1)
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                             #keyPath(ChangeToken.zoneName), zoneID.zoneName,
                                             #keyPath(ChangeToken.ownerName), zoneID.ownerName)
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).first
    }
}
