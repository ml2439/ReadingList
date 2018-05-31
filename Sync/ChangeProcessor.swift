import Foundation
import CoreData

protocol ChangeProcessor {
    func processChangedLocalObjects(_ objects: [NSManagedObject])
    var fetchRequestForLocallyTrackedObjects: NSFetchRequest<NSFetchRequestResult>? { get }

    func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>], completion: () -> ())
    func fetchLatestRemoteRecords()
}
