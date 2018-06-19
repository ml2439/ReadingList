import Foundation
import CoreData
import CloudKit

@objc(Book)
class Book: NSManagedObject {
    @NSManaged var readState: BookReadState
    @NSManaged var startedReading: Date?
    @NSManaged var finishedReading: Date?

    @NSManaged var isbn13: String?
    @NSManaged var googleBooksId: String?

    @NSManaged var title: String
    @NSManaged private(set) var authors: [Author]
    @NSManaged private(set) var authorSort: String // Calculated sort helper

    @NSManaged var pageCount: NSNumber?
    @NSManaged var publicationDate: Date?
    @NSManaged var bookDescription: String?
    @NSManaged var coverImage: Data?
    @NSManaged var notes: String?
    @NSManaged var currentPage: NSNumber?
    @NSManaged var sort: NSNumber?

    @NSManaged var subjects: Set<Subject>
    @NSManaged private(set) var lists: Set<List>

    // Raw value of a BookKey option set. Represents the keys which have been modified locally but
    // not uploaded to a remote store.
    @NSManaged private var keysPendingRemoteUpdate: Int32

    func addPendingRemoteUpdateKeys(_ keys: [BookCKRecordKey]) {
        let newKeysPendingRemoteUpdate = BookCKRecordKey.Bitmask.unionAll(keys.map { $0.bitmask })
        let newValue = BookCKRecordKey.Bitmask(rawValue: keysPendingRemoteUpdate).union(newKeysPendingRemoteUpdate).rawValue
        if keysPendingRemoteUpdate != newValue {
            keysPendingRemoteUpdate = newValue
        }
    }

    func removePendingRemoteUpdateKeys(_ keys: [BookCKRecordKey]) {
        let newKeysNotPendingRemoteUpdate = BookCKRecordKey.Bitmask.unionAll(keys.map { $0.bitmask })
        var newValue = BookCKRecordKey.Bitmask(rawValue: keysPendingRemoteUpdate)
        newValue.remove(newKeysNotPendingRemoteUpdate)
        if keysPendingRemoteUpdate != newValue.rawValue {
            keysPendingRemoteUpdate = newValue.rawValue
        }
    }

    static let pendingRemoteUpdatesPredicate = NSPredicate(format: "%K != 0", #keyPath(Book.keysPendingRemoteUpdate))

    @NSManaged var remoteIdentifier: String?
    @NSManaged private var ckRecordEncodedSystemFields: Data?

    convenience init(context: NSManagedObjectContext, readState: BookReadState) {
        self.init(context: context)
        self.readState = readState
        if readState == .reading {
            startedReading = Date()
        }
        if readState == .finished {
            startedReading = Date()
            finishedReading = Date()
        }
    }

    override func willSave() {
        super.willSave()

        // The sort manipulation should be in a method which allows setting of dates
        if readState == .toRead && sort == nil {
            let maxSort = Book.maxSort(fromContext: managedObjectContext!) ?? 0
            self.sort = (maxSort + 1).nsNumber
        }

        // Sort is not (yet) supported for non To Read books
        if readState != .toRead && sort != nil {
            self.sort = nil
        }

        // Update the modified keys record for Books which have a remote identifier, but only
        // on the viewContext.
        if managedObjectContext == PersistentStoreManager.container.viewContext && remoteIdentifier != nil {
            let keysPendingRemoteUpdate = changedValues().keys.compactMap { BookCKRecordKey.from(coreDataKey: $0) }.distinct()
            addPendingRemoteUpdateKeys(keysPendingRemoteUpdate)
            print("Updated bitmask: \(keysPendingRemoteUpdate.map { $0.rawValue }.joined(separator: ", "))")
        } else {
            print("Skipped updating bitmask")
        }
    }

    override func prepareForDeletion() {
        super.prepareForDeletion()
        for orphanedSubject in subjects.filter({ $0.books.count == 1 }) {
            orphanedSubject.delete()
            print("orphaned subject \(orphanedSubject.name) deleted.")
        }

        if managedObjectContext == PersistentStoreManager.container.viewContext,
            let existingRemoteRecord = self.storedCKRecordSystemFields() {
            PendingRemoteDeletionItem(context: managedObjectContext!, ckRecordID: existingRemoteRecord.recordID)
            print("Created a remote deletion object")
        } else {
            print("Skipping creation of remote deletion object")
        }
    }
}

extension Book {

    func setAuthors(_ authors: [Author]) {
        self.authors = authors
        self.authorSort = Author.authorSort(authors)
    }

    // FUTURE: make a convenience init which takes a fetch result?
    func populate(fromFetchResult fetchResult: GoogleBooks.FetchResult) {
        googleBooksId = fetchResult.id
        title = fetchResult.title
        populateAuthors(fromStrings: fetchResult.authors)
        bookDescription = fetchResult.description
        subjects = Set(fetchResult.subjects.map { Subject.getOrCreate(inContext: self.managedObjectContext!, withName: $0) })
        coverImage = fetchResult.coverImage
        pageCount = fetchResult.pageCount?.nsNumber
        publicationDate = fetchResult.publishedDate
        isbn13 = fetchResult.isbn13
    }

    func populate(fromSearchResult searchResult: GoogleBooks.SearchResult, withCoverImage coverImage: Data? = nil) {
        googleBooksId = searchResult.id
        title = searchResult.title
        populateAuthors(fromStrings: searchResult.authors)
        isbn13 = searchResult.isbn13
        self.coverImage = coverImage
    }

    private func populateAuthors(fromStrings authors: [String]) {
        let authorNames: [(String?, String)] = authors.map {
            if let range = $0.range(of: " ", options: .backwards) {
                let firstNames = $0[..<range.upperBound].trimming()
                let lastName = $0[range.lowerBound...].trimming()

                return (firstNames: firstNames, lastName: lastName)
            } else {
                return (firstNames: nil, lastName: $0)
            }
        }

        self.setAuthors(authorNames.map { Author(lastName: $0.1, firstNames: $0.0) })
    }

    static func get(fromContext context: NSManagedObjectContext, googleBooksId: String? = nil, isbn: String? = nil) -> Book? {
        // if both are nil, leave early
        guard googleBooksId != nil || isbn != nil else { return nil }

        // First try fetching by google books ID
        if let googleBooksId = googleBooksId {
            let googleBooksfetch = NSManagedObject.fetchRequest(Book.self, limit: 1)
            googleBooksfetch.predicate = NSPredicate(format: "%K == %@", #keyPath(Book.googleBooksId), googleBooksId)
            googleBooksfetch.returnsObjectsAsFaults = false
            if let result = (try! context.fetch(googleBooksfetch)).first { return result }
        }

        // then try fetching by ISBN
        if let isbn = isbn {
            let isbnFetch = NSManagedObject.fetchRequest(Book.self, limit: 1)
            isbnFetch.predicate = NSPredicate(format: "%K == %@", #keyPath(Book.isbn13), isbn)
            isbnFetch.returnsObjectsAsFaults = false
            return (try! context.fetch(isbnFetch)).first
        }

        return nil
    }

    static func maxSort(fromContext context: NSManagedObjectContext) -> Int32? {
        // FUTURE: Could use a fetch expression to just return the max value
        let fetchRequest = NSManagedObject.fetchRequest(Book.self, limit: 1)
        fetchRequest.predicate = NSPredicate(format: "%K == %ld", #keyPath(Book.readState), BookReadState.toRead.rawValue)
        fetchRequest.sortDescriptors = [NSSortDescriptor(\Book.sort, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).first?.sort?.int32
    }

    enum ValidationError: Error {
        case missingTitle
        case invalidIsbn
        case invalidReadDates
        case bitmaskPresentWithoutRemoteIdentifier
    }

    override func validateForUpdate() throws {
        try super.validateForUpdate()

        // FUTURE: these should be property validators, not in validateForUpdate
        if title.isEmptyOrWhitespace { throw ValidationError.missingTitle }
        if let isbn = isbn13, ISBN13(isbn) == nil { throw ValidationError.invalidIsbn }

        // FUTURE: Check read state with current page
        if readState == .toRead && (startedReading != nil || finishedReading != nil) { throw ValidationError.invalidReadDates }
        if readState == .reading && (startedReading == nil || finishedReading != nil) { throw ValidationError.invalidReadDates }
        if readState == .finished && (startedReading == nil || finishedReading == nil
            || startedReading!.startOfDay() > finishedReading!.startOfDay()) {
            throw ValidationError.invalidReadDates
        }

        if keysPendingRemoteUpdate != 0 && remoteIdentifier == nil {
            throw ValidationError.bitmaskPresentWithoutRemoteIdentifier
        }
    }

    func startReading() {
        guard readState == .toRead else { print("Attempted to start a book in state \(readState)"); return }
        readState = .reading
        startedReading = Date()
    }

    func finishReading() {
        guard readState == .reading else { print("Attempted to finish a book in state \(readState)"); return }
        readState = .finished
        finishedReading = Date()
    }

    func updateReadState() {
        if startedReading == nil {
            readState = .toRead
        } else if finishedReading == nil {
            readState = .reading
        } else {
            readState = .finished
        }
    }
}

extension Book {

    func storedCKRecordSystemFields() -> CKRecord? {
        guard let systemFieldsData = ckRecordEncodedSystemFields else { return nil }
        return CKRecord(systemFieldsData: systemFieldsData)!
    }

    func storeCKRecordSystemFields(_ ckRecord: CKRecord?) {
        ckRecordEncodedSystemFields = ckRecord?.encodedSystemFields()
    }

    func CKRecordForInsert(zoneID: CKRecordZoneID) -> CKRecord {
        guard remoteIdentifier == nil && ckRecordEncodedSystemFields == nil else { fatalError("Unexpected attempt to insert a record which already exists.") }
        let ckRecord = CKRecord(recordType: "Book", zoneID: zoneID)
        for key in BookCKRecordKey.all {
            ckRecord[key] = key.value(from: self)
        }
        return ckRecord
    }

    func CKRecordForDifferentialUpdate() -> CKRecord {
        guard let ckRecord = storedCKRecordSystemFields() else { fatalError("No stored CKRecord to use for differential update") }
        let changedKeys = BookCKRecordKey.Bitmask(rawValue: keysPendingRemoteUpdate)
        for key in BookCKRecordKey.all.filter({ changedKeys.contains($0.bitmask) }) {
            ckRecord[key] = key.value(from: self)
        }
        return ckRecord
    }

    func updateFrom(serverRecord: CKRecord) {
        if let existingCKRecordSystemFields = storedCKRecordSystemFields(), existingCKRecordSystemFields.recordChangeTag == serverRecord.recordChangeTag {
            print("CKRecord has same change tag; skipping update")
            return
        }

        if remoteIdentifier != serverRecord.recordID.recordName {
            print("Updating remoteIdentifier for book")
            remoteIdentifier = serverRecord.recordID.recordName
        }

        storeCKRecordSystemFields(serverRecord)

        for key in BookCKRecordKey.all {
            key.setValue(serverRecord[key], for: self)
        }
    }

    static func withRemoteIdentifiers(_ ids: [String]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}
