import Foundation
import CoreData

/// A representation of the remote record corresponding to an object
public protocol RemoteRecord { }

public typealias RemoteRecordID = String

enum RemoteRecordChange {
    case insert(RemoteRecord)
    case update(RemoteRecord)
    case delete(RemoteRecordID)
}

enum RemoteError {
    case permanent([RemoteRecordID])
    case temporary

    var isPermanent: Bool {
        switch self {
        case .permanent: return true
        default: return false
        }
    }
}

protocol Remote {
    func setupSubscription()
    func fetchUserID(completion: @escaping (RemoteRecordID?) -> Void)

    // Downstream
    func fetchAllRecords(completion: @escaping ([RemoteRecord]) -> Void)
    func fetchRecordChanges(completion: @escaping ([RemoteRecordChange], @escaping (_ success: Bool) -> Void) -> Void)

    // Upstream
    func upload(_ records: [NSManagedObject], completion: @escaping ([NSManagedObject: RemoteRecord], RemoteError?) -> Void)
    func update(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void)
    func remove(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void)
}
