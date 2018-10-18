import Foundation
import CoreData
import CloudKit

class BookUploader: BookUpstreamChangeProcessor {

    init(_ context: NSManagedObjectContext, _ remote: BookCloudKitRemote) {
        self.context = context
        self.remote = remote
    }

    let debugDescription = String(describing: BookUploader.self)
    let context: NSManagedObjectContext
    let remote: BookCloudKitRemote

    private enum UploadType {
        case insert
        case update
    }

    func processLocalChanges(_ books: [Book], completion: @escaping () -> Void) {

        // Map the local Books to CKRecords. These are either records for insertion, or records for differential updates.
        // The changed keys should be stored now, since we lose that information after the upload has occurred.
        let booksAndCKRecords = books.map { book -> (book: Book, uploadType: UploadType, ckRecord: CKRecord, delta: [BookCKRecordKey]) in
            let ckRecord: CKRecord
            let uploadType: UploadType
            if book.remoteIdentifier == nil {
                uploadType = .insert
                ckRecord = book.CKRecordForInsert(zoneID: remote.bookZoneID)
            } else {
                uploadType = .update
                ckRecord = book.CKRecordForDifferentialUpdate()
            }
            return (book, uploadType, ckRecord, ckRecord.changedBookKeys())
        }

        // Initiate the upload of the CKRecords
        let insertionCount = booksAndCKRecords.filter { $0.uploadType == .insert }.count
        print("Beginning upload of \(insertionCount) insertions and \(booksAndCKRecords.count - insertionCount) updates.")
        remote.upload(booksAndCKRecords.map { $0.ckRecord }) { [unowned self] error in
            self.context.perform {
                print("Upload complete. Processing results...")
                
                var innerErrors: [CKRecord.ID: CKError]?
                if let ckError = error as? CKError {
                    print("Remote upload resulted in an error with code \(ckError.code.rawValue)")
                    switch ckError.strategy {
                    case let .handleInnerErrors(errors):
                        innerErrors = errors
                    case .retryLater(_),
                         .retrySmallerBatch:
                        return
                    default:
                        print("Unhandled error!")
                        return
                    }
                }

                for (localBook, uploadType, ckRecord, delta) in booksAndCKRecords {
                    // If the book has since been deleted, ignore it. A remote deletion will (should) be pushed.
                    guard !localBook.isDeleted else { continue }
                    if let error = innerErrors?[ckRecord.recordID] {
                        print("Handling error of type \(error.code.rawValue) for record \(ckRecord.recordID.recordName)")
                        if error.code == .serverRecordChanged {
                            // We have tried to push a delta to the server, but the server record was different.
                            // This indicates that there has been some other push to the server which this device has not
                            // yet fetched. Our strategy is to wait until we have fetched the latest remove change before
                            // pushing this change back.
                            print("Server record changed - skipping upload.")
                        }
                        continue
                    }

                    // Assign the system fields and remote identifier.
                    localBook.storeCKRecordSystemFields(ckRecord)

                    // If this was an insertion, then the changed-field bitmask will not have been updated
                    // to account for any changes since the upload was initiated. We should check that all in the book
                    // have the same value as in the uploaded CKRecord. Those fields which differ should be marked as
                    // changed, to be picked up by the next upload cycle.

                    // If this was a differential update, then we should check whether the local values of the uploaded
                    // fields are the same before we remove them from the changed-field bitmask. We don't need to check
                    // any other fields, since the view context will have kept the bitmask up-to-date.

                    switch uploadType {
                    case .insert:
                        localBook.remoteIdentifier = ckRecord.recordID.recordName
                        let differingKeys = BookCKRecordKey.allCases.filter {
                            !CKRecord.valuesAreEqual(left: $0.value(from: localBook), right: ckRecord[$0])
                        }
                        if !differingKeys.isEmpty {
                            print("Inserted book record \(ckRecord.recordID.recordName) is now different to local book; adding bitmask.")
                            localBook.addPendingRemoteUpdateKeys(differingKeys)
                        }
                    case .update:
                        let updatedKeys = delta.filter {
                            CKRecord.valuesAreEqual(left: $0.value(from: localBook), right: ckRecord[$0])
                        }
                        localBook.removePendingRemoteUpdateKeys(updatedKeys)
                        if updatedKeys.count != delta.count {
                            print("\(delta.count - updatedKeys.count) of \(delta.count) updated book fields now differ " +
                                "from the uploaded record; not removing bitmask for these fields.")
                        }
                    }
                }

                self.context.saveAndLogIfErrored()
                completion()
            }
        }
    }

    var unprocessedChangedBooksRequest: NSFetchRequest<Book> = {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = NSPredicate.or([
            Book.pendingRemoteUpdatesPredicate,
            NSPredicate(format: "%K = nil", #keyPath(Book.remoteIdentifier))
        ])
        fetchRequest.fetchBatchSize = 50
        return fetchRequest
    }()
}
