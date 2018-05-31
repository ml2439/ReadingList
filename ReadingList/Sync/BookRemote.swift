import Foundation

extension Book: RemoteObject { }

class BookConsoleRemote: Remote {
    typealias Record = RemoteBook
    typealias Object = Book
    
    func setupMoodSubscription() {
        print("Setting up mood subscription")
    }

    func fetchLatest(completion: @escaping ([Record]) -> ()) {
        print("Fetching latest")
        completion([])
    }

    func fetchNew(completion: @escaping ([RemoteRecordChange<Record>], @escaping (_ success: Bool) -> ()) -> ()) {
        print("Fetching new books")
        completion([], { _ in })
    }

    func upload(_ records: [Object], completion: @escaping ([Record], RemoteError?) -> ()) {
        print("Uploading \(records.count) records")
        completion([], nil)
    }

    func remove(_ records: [Object], completion: @escaping ([RemoteRecordID], RemoteError?) -> ()) {
        print("Removing \(records.count) records")
        completion([], nil)
    }

    func fetchUserID(completion: @escaping (RemoteRecordID?) -> ()) {
        print("Fetching user ID")
        completion(nil)
    }
}

class RemoteBook: RemoteRecord {
    
}
