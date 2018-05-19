import Foundation
import CoreData

protocol ChangeProcessor {
    func processChangedLocalObjects(_ objects: [NSManagedObject])
    func fetchRequestForLocallyTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>?

    func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>], completion: () -> ())
    func fetchLatestRemoteRecords()
}
