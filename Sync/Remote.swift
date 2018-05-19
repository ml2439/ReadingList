import Foundation
import CoreData

/// An object for which there may exist remote records
public protocol RemoteObject: class { }

/// A representation of the remote record corresponding to an object
public protocol RemoteRecord { }

public typealias RemoteRecordID = String

enum RemoteRecordChange<T: RemoteRecord> {
    case insert(T)
    case update(T)
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
    associatedtype Record: RemoteRecord
    associatedtype Object: RemoteObject
    
    func setupMoodSubscription()
    func fetchLatest(completion: @escaping ([Record]) -> ())
    func fetchNew(completion: @escaping ([RemoteRecordChange<Record>], @escaping (_ success: Bool) -> ()) -> ())
    func upload(_ records: [Object], completion: @escaping ([Record], RemoteError?) -> ())
    func remove(_ records: [Object], completion: @escaping ([RemoteRecordID], RemoteError?) -> ())
    func fetchUserID(completion: @escaping (RemoteRecordID?) -> ())
}
