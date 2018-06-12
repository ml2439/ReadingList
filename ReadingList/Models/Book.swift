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
    @NSManaged private(set) var authors: NSOrderedSet
    @NSManaged private(set) var authorDisplay: String // Denormalised attribute to reduce required fetches
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

    static let pendingRemoteUpdatesPredicate = NSPredicate(format: "%K != 0", #keyPath(Book.keysPendingRemoteUpdate))

    // Pending remote deletion flag should never get un-done. Hence, it cannot be set publicly, and can
    // only be set to "true" via a public function.
    @NSManaged private(set) var pendingRemoteDeletion: Bool
    func markForDeletion() { pendingRemoteDeletion = true }

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
        let changedKeys = changedValues().keys
        if !changedKeys.contains(#keyPath(Book.ckRecordEncodedSystemFields)) {

            let newKeysPendingRemoteUpdate = BookKey.union(changedKeys.compactMap { BookKey.from(coreDataKey: $0) })
            if newKeysPendingRemoteUpdate != BookKey(rawValue: keysPendingRemoteUpdate) {
                keysPendingRemoteUpdate = newKeysPendingRemoteUpdate.rawValue
            }
        }
    }

    override func prepareForDeletion() {
        super.prepareForDeletion()
        for orphanedSubject in subjects.filter({ $0.books.count == 1 }) {
            orphanedSubject.delete()
            print("orphaned subject \(orphanedSubject.name) deleted.")
        }
    }
}

private struct BookKey: OptionSet {
    let rawValue: Int32

    static let title = BookKey(rawValue: 1 << 0)
    static let authors = BookKey(rawValue: 1 << 1)
    static let cover = BookKey(rawValue: 1 << 2)
    static let googleBooksId = BookKey(rawValue: 1 << 3)
    static let isbn13 = BookKey(rawValue: 1 << 4)
    static let pageCount = BookKey(rawValue: 1 << 5)
    static let publicationDate = BookKey(rawValue: 1 << 6)
    static let bookDescription = BookKey(rawValue: 1 << 7)
    static let coverImage = BookKey(rawValue: 1 << 8)
    static let notes = BookKey(rawValue: 1 << 9)
    static let currentPage = BookKey(rawValue: 1 << 10)
    static let sort = BookKey(rawValue: 1 << 11)
    static let startedReading = BookKey(rawValue: 1 << 12)
    static let finishedReading = BookKey(rawValue: 1 << 13)

    static func from(coreDataKey: String) -> BookKey? { //swiftlint:disable:this cyclomatic_complexity
        switch coreDataKey {
        case #keyPath(Book.title): return .title
        case #keyPath(Book.authors): return .authors
        case #keyPath(Book.coverImage): return .cover
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

    static func union(_ keys: [BookKey]) -> BookKey {
        var key = BookKey(rawValue: 0)
        keys.forEach { key.formUnion($0) }
        return key
    }
}

extension Book {

    func setAuthors(_ authors: [Author]) {
        self.authors = NSOrderedSet(array: authors)
        self.authorSort = Author.authorSort(authors)
        self.authorDisplay = Author.authorDisplay(authors)
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
        // FUTURE: This is a bit brute force, deleting all existing authors. Could perhaps inspect for changes first.
        self.authors.map { $0 as! Author }.forEach { $0.delete() }
        self.setAuthors(authorNames.map { Author(context: self.managedObjectContext!, lastName: $0.1, firstNames: $0.0) })
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

extension Book {

    func getStoredCKRecord() -> CKRecord? {
        guard let systemFieldsData = ckRecordEncodedSystemFields else { return nil }
        return CKRecord(systemFieldsData: systemFieldsData)!
    }

    func toCKRecord(bookZoneID: CKRecordZoneID) -> CKRecord {
        let ckRecord: CKRecord
        // If the CKRecord already exists, create the record from the stored system fields,
        // and add any modified keys to the record.
        let uploadAllKeys: Bool
        if let systemFieldsData = ckRecordEncodedSystemFields {
            ckRecord = CKRecord(systemFieldsData: systemFieldsData)!
            uploadAllKeys = false
        } else {
            // Otherwise, create a new CKRecord and store the generated remote ID
            ckRecord = CKRecord(recordType: "Book", zoneID: bookZoneID)
            remoteIdentifier = ckRecord.recordID.recordName
            uploadAllKeys = true
        }

        // We want to include only the modified keys, unless this is a new CKRecord, in which case
        // we should include all keys.
        let modifiedKeys = BookKey(rawValue: keysPendingRemoteUpdate)
        func setValue(_ value: Any?, ifModified: BookKey, forKey key: String) {
            if uploadAllKeys || modifiedKeys.contains(ifModified) {
                ckRecord.setValue(value, forKey: key)
            }
        }

        setValue(title, ifModified: .title, forKey: "title")
        setValue(googleBooksId, ifModified: .googleBooksId, forKey: "googleBooksId")
        setValue(isbn13, ifModified: .isbn13, forKey: "isbn13")
        setValue(pageCount, ifModified: .pageCount, forKey: "pageCount")
        setValue(publicationDate, ifModified: .publicationDate, forKey: "publicationDate")
        setValue(bookDescription, ifModified: .bookDescription, forKey: "bookDescription")
        setValue(notes, ifModified: .notes, forKey: "notes")
        setValue(currentPage, ifModified: .currentPage, forKey: "currentPage")
        setValue(sort, ifModified: .sort, forKey: "sort")
        setValue(startedReading, ifModified: .startedReading, forKey: "startedReading")
        setValue(finishedReading, ifModified: .finishedReading, forKey: "finishedReading")

        if uploadAllKeys || modifiedKeys.contains(.coverImage) {
            let imageFilePath = URL.temporary()
            FileManager.default.createFile(atPath: imageFilePath.path, contents: coverImage, attributes: nil)
            ckRecord.setValue(CKAsset(fileURL: imageFilePath), forKey: "coverImage")
        }
        if uploadAllKeys || modifiedKeys.contains(.authors) {
            let allAuthorNames = authors.map { $0 as! Author }.flatMap { [$0.firstNames, $0.lastName] }
            ckRecord.setValue(allAuthorNames, forKey: "authors")
        }

        return ckRecord
    }

    func update(from ckRecord: CKRecord) {
        ckRecordEncodedSystemFields = ckRecord.encodedSystemFields()
        remoteIdentifier = ckRecord.recordID.recordName

        // A CKRecord will only include a delta of the record; rather than assign all values from it,
        // we should assign those values which correspond to present keys.
        let presentKeys = ckRecord.allKeys()
        func ifKeyPresent(_ key: String, perform: (Any?) -> Void) {
            guard presentKeys.contains(key) else { return }
            perform(ckRecord.value(forKey: key))
        }
        ifKeyPresent("title") { title = $0 as! String }
        ifKeyPresent("googleBooksId") { googleBooksId = $0 as? String }
        ifKeyPresent("isbn13") { isbn13 = $0 as? String }
        ifKeyPresent("pageCount") { pageCount = $0 as? NSNumber }
        ifKeyPresent("publicationDate") { publicationDate = $0 as? Date }
        ifKeyPresent("bookDescription") { bookDescription = $0 as? String }
        ifKeyPresent("notes") { notes = $0 as? String }
        ifKeyPresent("currentPage") { currentPage = $0 as? NSNumber }
        ifKeyPresent("sort") { sort = $0 as? NSNumber }
        ifKeyPresent("startedReading") { startedReading = $0 as? Date }
        ifKeyPresent("finishedReading") { finishedReading = $0 as? Date }
        ifKeyPresent("coverImage") {
            if let imageAsset = $0 as? CKAsset {
                coverImage = FileManager.default.contents(atPath: imageAsset.fileURL.path)
            } else {
                coverImage = nil
            }
        }
        ifKeyPresent("authors") {
            guard let allAuthorNames = $0 as? [String?] else { fatalError("A differential update tried to set authors to nil") }
            guard allAuthorNames.count % 2 == 0 else { fatalError("Author names update must be even in length") }

            authors.map { $0 as! Author }.forEach { $0.delete() }
            var newAuthors = [Author]()
            for authorIndex in 0..<allAuthorNames.count / 2 {
                newAuthors.append(Author(context: self.managedObjectContext!, lastName: allAuthorNames[authorIndex + 1]!, firstNames: allAuthorNames[authorIndex]))
            }
            setAuthors(newAuthors)
        }

        // Set the read state according to the resulting reading dates, if the CKRecord involved changes to the dates
        if presentKeys.contains("startedReading") || presentKeys.contains("finishedReading") {
            if startedReading != nil && finishedReading != nil {
                readState = .finished
            } else if startedReading != nil && finishedReading == nil {
                readState = .reading
            } else if startedReading == nil && finishedReading == nil {
                readState = .toRead
            }
        }
    }

    static var notMarkedForDeletion: NSPredicate {
        return NSPredicate(format: "%K == false", #keyPath(Book.pendingRemoteDeletion))
    }

    static func withRemoteIdentifiers(_ ids: [String]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}
