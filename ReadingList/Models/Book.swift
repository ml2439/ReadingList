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

    func addPendingRemoteUpdateKeys(_ keys: [BookKey]) {
        let newKeysPendingRemoteUpdate = BookKey.Bitmask.unionAll(keys.map { $0.bitmask })
        let newValue = BookKey.Bitmask(rawValue: keysPendingRemoteUpdate).union(newKeysPendingRemoteUpdate).rawValue
        if keysPendingRemoteUpdate != newValue {
            keysPendingRemoteUpdate = newValue
        }
    }

    func removePendingRemoteUpdateKeys(_ keys: [BookKey]) {
        let newKeysNotPendingRemoteUpdate = BookKey.Bitmask.unionAll(keys.map { $0.bitmask })
        var newValue = BookKey.Bitmask(rawValue: keysPendingRemoteUpdate)
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

        // Update the modified keys record, if this change hasn't also updated the CKRecord.
        // The justification of this is that the CKRecord is always updated by remote changes,
        // and *those* do not need to be posted back to the remote server. Changes originating
        // locally, however, will not change the CKRecord, and thus should be posted to the server.
        if managedObjectContext?.name == SyncCoordinator.ContextName.viewContext.rawValue {
            let keysPendingRemoteUpdate = changedValues().keys.compactMap { BookKey.from(coreDataKey: $0) }
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

        if managedObjectContext?.name == SyncCoordinator.ContextName.viewContext.rawValue,
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
}

/**
 Encapsulates the mapping between Book objects and CKRecord values, and additionally
 holds a Bitmask struct which is able to form Int32 bitmask values based on a collection
 of these BookKey values, for use in storing keys which are pending remote updates.
*/
enum BookKey: String { //swiftlint:disable redundant_string_enum_value
    // Note: the ordering of these cases matters. The position determines the value used when forming a bitmask
    case title = "title"
    case authors = "authors"
    case googleBooksId = "googleBooksId"
    case isbn13 = "isbn13"
    case pageCount = "pageCount"
    case publicationDate = "publicationDate"
    case bookDescription = "bookDescription"
    case coverImage = "coverImage"
    case notes = "notes"
    case currentPage = "currentPage"
    case sort = "sort"
    case startedReading = "startedReading"
    case finishedReading = "finishedReading" //swiftlint:enable redundant_string_enum_value

    static let all: [BookKey] = [.title, .authors, .googleBooksId, .isbn13, .pageCount, .publicationDate, .bookDescription,
                                 .coverImage, .notes, .currentPage, .sort, .startedReading, .finishedReading]

    struct Bitmask: OptionSet {
        let rawValue: Int32

        static func unionAll(_ values: [Bitmask]) -> Bitmask {
            var result = Bitmask(rawValue: 0)
            for value in values {
                result.formUnion(value)
            }
            return result
        }
    }

    var bitmask: Bitmask {
        return Bitmask(rawValue: 1 << BookKey.all.index(of: self)!)
    }

    static func from(coreDataKey: String) -> BookKey? { //swiftlint:disable:this cyclomatic_complexity
        switch coreDataKey {
        case #keyPath(Book.title): return .title
        case #keyPath(Book.authors): return .authors
        case #keyPath(Book.coverImage): return .coverImage
        case #keyPath(Book.googleBooksId): return .googleBooksId
        case #keyPath(Book.isbn13): return .isbn13
        case #keyPath(Book.pageCount): return .pageCount
        case #keyPath(Book.publicationDate): return .publicationDate
        case #keyPath(Book.bookDescription): return .bookDescription
        case #keyPath(Book.notes): return .notes
        case #keyPath(Book.currentPage): return .currentPage
        case #keyPath(Book.sort): return .sort
        case #keyPath(Book.startedReading): return .startedReading
        case #keyPath(Book.finishedReading): return .finishedReading
        default: return nil
        }
    }

    func value(from book: Book) -> CKRecordValue? { //swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .title: return book.title as NSString
        case .googleBooksId: return book.googleBooksId as NSString?
        case .isbn13: return book.isbn13 as NSString?
        case .pageCount: return book.pageCount
        case .publicationDate: return book.publicationDate as NSDate?
        case .bookDescription: return book.bookDescription as NSString?
        case .notes: return book.notes as NSString?
        case .currentPage: return book.currentPage
        case .sort: return book.sort
        case .startedReading: return book.startedReading as NSDate?
        case .finishedReading: return book.finishedReading as NSDate?
        case .authors: return NSKeyedArchiver.archivedData(withRootObject: book.authors) as NSData
        case .coverImage:
            guard let coverImage = book.coverImage else { return nil }
            let imageFilePath = URL.temporary()
            FileManager.default.createFile(atPath: imageFilePath.path, contents: coverImage, attributes: nil)
            return CKAsset(fileURL: imageFilePath)
        }
    }

    func setValue(_ value: CKRecordValue?, for book: Book) { //swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .title: book.title = value as! String
        case .googleBooksId: book.googleBooksId = value as? String
        case .isbn13: book.isbn13 = value as? String
        case .pageCount: book.pageCount = value as? NSNumber
        case .publicationDate: book.publicationDate = value as? Date
        case .bookDescription: book.bookDescription = value as? String
        case .notes: book.notes = value as? String
        case .currentPage: book.currentPage = value as? NSNumber
        case .sort: book.sort = value as? NSNumber
        case .startedReading: book.startedReading = value as? Date
        case .finishedReading: book.finishedReading = value as? Date
        case .authors:
            book.setAuthors(NSKeyedUnarchiver.unarchiveObject(with: value as! Data) as! [Author])
        case .coverImage:
            guard let imageAsset = value as? CKAsset else { book.coverImage = nil; return }
            //book.coverImage = FileManager.default.contents(atPath: imageAsset.fileURL.path)
            // TODO: Disabled to allow merges to work. Conditionally disable / investigate
        }
    }
}

extension CKRecord {
    subscript (_ key: BookKey) -> CKRecordValue? {
        get { return self.object(forKey: key.rawValue) }
        set { self.setObject(newValue, forKey: key.rawValue) }
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
        for key in BookKey.all {
            ckRecord[key] = key.value(from: self)
        }
        return ckRecord
    }

    func CKRecordForDifferentialUpdate() -> CKRecord {
        guard let ckRecord = storedCKRecordSystemFields() else { fatalError("No stored CKRecord to use for differential update") }
        let changedKeys = BookKey.Bitmask(rawValue: keysPendingRemoteUpdate)
        for key in BookKey.all.filter({ changedKeys.contains($0.bitmask) }) {
            ckRecord[key] = key.value(from: self)
        }
        return ckRecord
    }

    func updateFrom(ckRecord: CKRecord) {
        // TODO: Check whether updated-to-nil keys are included in this
        for key in ckRecord.allKeys().compactMap({ BookKey(rawValue: $0) }) {
            key.setValue(ckRecord[key], for: self)
        }
    }

    static func withRemoteIdentifiers(_ ids: [String]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}
