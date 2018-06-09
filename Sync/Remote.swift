import Foundation
import CoreData

/// A representation of the remote record corresponding to an object
public protocol RemoteRecord {
    var id: RemoteRecordID? { get }
}

public typealias RemoteRecordID = String

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

    // Downstream
    func fetchRecordChanges(completion: @escaping ([RemoteRecord], [RemoteRecordID]) -> Void)

    // Upstream
    func upload(_ records: [NSManagedObject], completion: @escaping ([RemoteRecord], RemoteError?) -> Void)
    func remove(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void)
}
