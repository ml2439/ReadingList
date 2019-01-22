import Foundation
import CoreData
import ReadingList_Foundation
import os.log

@objc(Book)
class Book: NSManagedObject {
    @NSManaged var readState: BookReadState
    @NSManaged var startedReading: Date?
    @NSManaged var finishedReading: Date?

    @NSManaged var isbn13: NSNumber?
    @NSManaged var googleBooksId: String?
    @NSManaged var manualBookId: String?

    @NSManaged var title: String
    @NSManaged private(set) var authors: [Author]
    @NSManaged private(set) var authorSort: String // Calculated sort helper

    @NSManaged var pageCount: NSNumber?
    @NSManaged var publicationDate: Date?
    @NSManaged var bookDescription: String?
    @NSManaged var coverImage: Data?
    @NSManaged var notes: String?
    @NSManaged var rating: NSNumber? // Valid values are 1-5.
    @NSManaged var languageCode: String? // ISO 639.1: two-digit language code
    @NSManaged var currentPage: NSNumber?
    @NSManaged var sort: NSNumber?

    @NSManaged var subjects: Set<Subject>
    @NSManaged private(set) var lists: Set<List>

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

        // FUTURE: willSave() is called after property validation, so if we add sort/readState validation
        // then this removal of the sort property will need to be done earlier.
        setSort()
    }

    private func setSort() {
        guard readState == .toRead else {
            if sort != nil { sort = nil }
            return
        }
        guard sort == nil else { return }

        if let maximalSort = Book.maximalSort(getMaximum: !UserSettings.addBooksToTopOfCustom.value, fromContext: managedObjectContext!) {
            let plusMinusOne: Int32 = UserSettings.addBooksToTopOfCustom.value ? -1 : 1
            sort = NSNumber(value: maximalSort + plusMinusOne)
        } else {
            sort = 0
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

extension Book {

    func setAuthors(_ authors: [Author]) {
        self.authors = authors
        self.authorSort = Author.authorSort(authors)
    }

    // FUTURE: make a convenience init which takes a fetch result?
    func populate(fromFetchResult fetchResult: FetchResult) {
        googleBooksId = fetchResult.id
        title = fetchResult.title
        populateAuthors(fromStrings: fetchResult.authors)
        bookDescription = fetchResult.description
        subjects = Set(fetchResult.subjects.map { Subject.getOrCreate(inContext: self.managedObjectContext!, withName: $0) })
        coverImage = fetchResult.coverImage
        pageCount = fetchResult.pageCount?.nsNumber
        publicationDate = fetchResult.publishedDate
        if let isbnInt = fetchResult.isbn13?.int {
            isbn13 = NSNumber(value: isbnInt)
        }
        languageCode = fetchResult.languageCode
    }

    func populate(fromSearchResult searchResult: SearchResult, withCoverImage coverImage: Data? = nil) {
        googleBooksId = searchResult.id
        title = searchResult.title
        populateAuthors(fromStrings: searchResult.authors)
        if let isbnInt = ISBN13(searchResult.isbn13)?.int {
            isbn13 = NSNumber(value: isbnInt)
        }
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

    /**
     Gets the "maximal" sort value of any book - i.e. either the maximum or minimum value.
    */
    static func maximalSort(getMaximum: Bool, fromContext context: NSManagedObjectContext) -> Int32? {
        // FUTURE: The following code works in the application, but crashes in tests.

        /*let request = NSManagedObject.fetchRequest(Book.self) as! NSFetchRequest<NSFetchRequestResult>
        request.resultType = .dictionaryResultType

        let key = "sort"
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = key
        expressionDescription.expression = NSExpression(forFunction: getMaximum ? "max:" : "min:", arguments: [NSExpression(forKeyPath: \Book.sort)])
        expressionDescription.expressionResultType = .integer32AttributeType
        request.propertiesToFetch = [expressionDescription]

        let result = try! context.fetch(request) as! [[String: Int32]]
        return result.first?[key]*/

        let fetchRequest = NSManagedObject.fetchRequest(Book.self, limit: 1)
        fetchRequest.predicate = NSPredicate.and([
            NSPredicate(format: "%K == %ld", #keyPath(Book.readState), BookReadState.toRead.rawValue),
            NSPredicate(format: "%K != nil", #keyPath(Book.sort))])
        fetchRequest.sortDescriptors = [NSSortDescriptor(\Book.sort, ascending: !getMaximum)]
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).first?.sort?.int32
    }

    static func maxSort(fromContext context: NSManagedObjectContext) -> Int32? {
        return maximalSort(getMaximum: true, fromContext: context)
    }

    static func minSort(fromContext context: NSManagedObjectContext) -> Int32? {
        return maximalSort(getMaximum: false, fromContext: context)
    }

    @objc func validateAuthors(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // nil authors property will be validated by the validation set on the model
        guard let authors = value.pointee as? [Author] else { return }
        if authors.isEmpty {
            throw BookValidationError.noAuthors.NSError()
        }
    }

    @objc func validateTitle(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // nil title property will be validated by the validation set on the model
        guard let title = value.pointee as? String else { return }
        if title.isEmptyOrWhitespace {
            throw BookValidationError.missingTitle.NSError()
        }
    }

    @objc func validateIsbn13(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        guard let isbn13 = value.pointee as? Int64 else { return }
        if !ISBN13.isValid(isbn13) {
            throw BookValidationError.invalidIsbn.NSError()
        }
    }

    @objc func validateLanguageCode(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        guard let languageCode = value.pointee as? String else { return }
        if Language.byIsoCode[languageCode] == nil {
            throw BookValidationError.invalidLanguageCode.NSError()
        }
    }

    override func validateForUpdate() throws {
        try super.validateForUpdate()
        try interPropertyValiatation()
    }

    override func validateForInsert() throws {
        try super.validateForInsert()
        try interPropertyValiatation()
    }

    func interPropertyValiatation() throws {
        switch readState {
        case .toRead:
            if startedReading != nil || finishedReading != nil {
                throw BookValidationError.invalidReadDates.NSError()
            }
        case .reading:
            if startedReading == nil || finishedReading != nil {
                throw BookValidationError.invalidReadDates.NSError()
            }
        case .finished:
            if startedReading == nil || finishedReading == nil {
                throw BookValidationError.invalidReadDates.NSError()
            }
        }
        if readState != .reading && currentPage != nil {
            throw BookValidationError.presentCurrentPage.NSError()
        }
        if googleBooksId == nil && manualBookId == nil {
            throw BookValidationError.missingIdentifier.NSError()
        }
        if googleBooksId != nil && manualBookId != nil {
            throw BookValidationError.conflictingIdentifiers.NSError()
        }
    }

    func startReading() {
        guard readState == .toRead else {
            os_log("Attempted to start a book in state %{public}s; was ignored.", type: .error, readState.description)
            return
        }
        readState = .reading
        startedReading = Date()
    }

    func finishReading() {
        guard readState == .reading else {
            os_log("Attempted to finish a book in state %{public}s; was ignored.", type: .error, readState.description)
            return
        }
        readState = .finished
        currentPage = nil
        finishedReading = Date()
    }
}

enum BookValidationError: Int {
    case missingTitle = 1
    case invalidIsbn = 2
    case invalidReadDates = 3
    case invalidLanguageCode = 4
    case missingIdentifier = 5
    case conflictingIdentifiers = 6
    case noAuthors = 7
    case presentCurrentPage = 8
}

extension BookValidationError {
    var description: String {
        switch self {
        case .missingTitle: return "Title must be non-empty or whitespace"
        case .invalidIsbn: return "Isbn13 must be a valid ISBN"
        case .invalidReadDates: return "StartedReading and FinishedReading must align with ReadState"
        case .invalidLanguageCode: return "LanguageCode must be an ISO-639.1 value"
        case .conflictingIdentifiers: return "GoogleBooksId and ManualBooksId cannot both be non nil"
        case .missingIdentifier: return "GoogleBooksId and ManualBooksId cannot both be nil"
        case .noAuthors: return "Authors array must be non-empty"
        case .presentCurrentPage: return "CurrentPage must be nil when not Currently Reading"
        }
    }

    func NSError() -> NSError {
        return Foundation.NSError(domain: "BookErrorDomain", code: self.rawValue, userInfo: [NSLocalizedDescriptionKey: self.description])
    }
}
