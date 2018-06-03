#if DEBUG
import Foundation
import CoreData

class BookConsoleRemoteRecord: RemoteRecord {
    var id: RemoteRecordID?

    init() {
        id = UUID().uuidString
    }
}

class BookConsoleRemote: Remote {
    private func output(_ string: String) {
        sleep(1)
        if DebugSettings.setConsoleRemoteOffline {
            print("REMOTE <OFFLINE>: \(string)")
        } else {
            print("REMOTE: \(string)")
        }
    }

    func setupSubscription() {
        output("Setting up subscription")
    }

    func fetchAllRecords(completion: @escaping ([RemoteRecord]) -> Void) {
        output("Fetching all records")
        completion([])
    }

    func fetchRecordChanges(completion: @escaping ([RemoteRecordChange], @escaping (_ success: Bool) -> Void) -> Void) {
        output("Fetching record changes")
        completion([]) { _ in }
    }

    private func reportErrorIfOffline(completion: ([RemoteRecordID], RemoteError?) -> Void) -> Bool {
        if DebugSettings.setConsoleRemoteOffline {
            completion([], .temporary)
            return true
        }
        return false
    }

    private func reportErrorIfOffline(completion: ([NSManagedObject: RemoteRecord], RemoteError?) -> Void) -> Bool {
        if DebugSettings.setConsoleRemoteOffline {
            completion([:], .temporary)
            return true
        }
        return false
    }

    func upload(_ records: [NSManagedObject], completion: @escaping ([NSManagedObject: RemoteRecord], RemoteError?) -> Void) {
        output("Uploading \(records.count) records")
        guard let books = records as? [Book] else { fatalError("Incorrect type") }

        if reportErrorIfOffline(completion: completion) { return }

        completion(books.reduce(into: [NSManagedObject: RemoteRecord]()) {
            $0[$1] = BookConsoleRemoteRecord()
        }, nil)
    }

    func update(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void) {
        output("Updating \(records.count) records")
        guard let books = records as? [Book] else { fatalError("Incorrect type") }

        if reportErrorIfOffline(completion: completion) { return }

        completion(books.compactMap { $0.remoteIdentifier }, nil)
    }

    func remove(_ records: [NSManagedObject], completion: @escaping ([RemoteRecordID], RemoteError?) -> Void) {
        output("Removing \(records.count) records")
        guard let books = records as? [Book] else { fatalError("Incorrect type") }

        if DebugSettings.setConsoleRemoteOffline {
            completion([], .temporary)
            return
        }

        completion(books.compactMap { $0.remoteIdentifier }, nil)
    }

    func fetchUserID(completion: @escaping (RemoteRecordID?) -> Void) {
        output("Fetching user ID")
        completion(nil)
    }
}

#endif
