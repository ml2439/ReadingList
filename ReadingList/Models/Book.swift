import Foundation
import CoreData

@objc enum BookReadState: Int16, CustomStringConvertible {
    case reading = 1
    case toRead = 2
    case finished = 3
    
    var description: String {
        switch self {
        case .reading: return "Reading"
        case .toRead: return "To Read"
        case .finished: return "Finished"
        }
    }
    
    var longDescription: String {
        switch self {
        case .toRead:
            return "📚 To Read"
        case .reading:
            return "📖 Currently Reading"
        case .finished:
            return "🎉 Finished"
        }
    }
}

@objc(Book)
class Book: NSManagedObject {
    @NSManaged var title: String
    @NSManaged var isbn13: String?
    @NSManaged var googleBooksId: String?
    @NSManaged var pageCount: NSNumber?
    @NSManaged var publicationDate: Date?
    @NSManaged var bookDescription: String?
    @NSManaged var coverImage: Data?
    @NSManaged var readState: BookReadState
    @NSManaged var startedReading: Date?
    @NSManaged var finishedReading: Date?
    @NSManaged var notes: String?
    @NSManaged var currentPage: NSNumber?
    @NSManaged var sort: NSNumber?
    @NSManaged var createdWhen: Date

    @NSManaged var subjects: Set<Subject>
    @NSManaged var lists: Set<List>
    @NSManaged var authors: NSOrderedSet
    
    @NSManaged func addAuthors(_ values: NSOrderedSet)
    @NSManaged func removeAuthors(_ values: NSSet)
    
    @NSManaged private(set) var authorDisplay: String // Denormalised attribute to reduce required fetches
    @NSManaged private(set) var authorSort: String // Calculated sort helper

    override func willSave() {
        super.willSave()

        if changedValues().contains(where: {$0.key == #keyPath(Book.authors)}) {
            let authorsArray = authors.map{$0 as! Author}
            let newAuthorSort = authorsArray.map {
                [$0.lastName, $0.firstNames].flatMap{$0?.sortable}.joined(separator: ".")
            }.joined(separator: "..")
            let newAuthorDisplay = authorsArray.map{$0.displayFirstLast}.joined(separator: ", ")
            if authorSort != newAuthorSort { authorSort = newAuthorSort }
            if authorDisplay != newAuthorDisplay { authorDisplay = newAuthorDisplay }
        }
        
        if readState == .toRead && sort == nil {
            let maxSort = Book.maxSort(fromContext: managedObjectContext!) ?? 0
            self.sort = (maxSort + 1).nsNumber
        }
    }
    
    override func prepareForDeletion() {
        super.prepareForDeletion()
        for orphanedSubject in subjects.filter({$0.books.count == 1}) {
            orphanedSubject.delete()
            print("orphaned subject \(orphanedSubject.name) deleted.")
        }
    }
    
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
    
    // FUTURE: make a convenience init which takes a fetch result?
    func populate(fromFetchResult fetchResult: GoogleBooks.FetchResult) {
        googleBooksId = fetchResult.id
        title = fetchResult.title
        populateAuthors(fromStrings: fetchResult.authors)
        bookDescription = fetchResult.description
        subjects = Set(fetchResult.subjects.map{Subject.getOrCreate(inContext: self.managedObjectContext!, withName: $0)})
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
        let authorNames: [(String?, String)] = authors.map{
            if let range = $0.range(of: " ", options: .backwards) {
                let firstNames = $0[..<range.upperBound].trimming()
                let lastName = $0[range.lowerBound...].trimming()
                
                return (firstNames: firstNames, lastName: lastName)
            }
            else {
                return (firstNames: nil, lastName: $0)
            }
        }
        // FUTURE: This is a bit brute force, deleting all existing authors. Could perhaps inspect for changes first.
        self.authors.map{$0 as! Author}.forEach{$0.delete()}
        self.authors = NSOrderedSet(array: authorNames.map{Author(context: self.managedObjectContext!, lastName: $0.1, firstNames: $0.0)})
    }
}

extension Book {
    
    static func get(fromContext context: NSManagedObjectContext, googleBooksId: String? = nil, isbn: String? = nil) -> Book? {
        // if both are nil, leave early
        guard googleBooksId != nil || isbn != nil else { return nil }
        
        // First try fetching by google books ID
        if let googleBooksId = googleBooksId {
            let googleBooksfetch = NSManagedObject.fetchRequest(Book.self, limit: 1)
            googleBooksfetch.predicate = NSPredicate(format: "%K == %@", #keyPath(Book.googleBooksId), googleBooksId)
            if let result = (try! context.fetch(googleBooksfetch)).first { return result }
        }
        
        // then try fetching by ISBN
        if let isbn = isbn {
            let isbnFetch = NSManagedObject.fetchRequest(Book.self, limit: 1)
            isbnFetch.predicate = NSPredicate(format: "%K == %@", #keyPath(Book.isbn13), isbn)
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
        case noAuthors
        case invalidReadDates
    }
    
    override func validateForUpdate() throws {
        try super.validateForUpdate()
        if let error = checkIsValid() { throw error }
    }
    
    func checkIsValid() -> Error? {
        if title.isEmptyOrWhitespace { return ValidationError.missingTitle }
        if let isbn = isbn13, ISBN13(isbn) == nil { return ValidationError.invalidIsbn }
        if authors.count == 0 { return ValidationError.noAuthors }
        if readState == .toRead && (startedReading != nil || finishedReading != nil) { return ValidationError.invalidReadDates }
        if readState == .reading && (startedReading == nil || finishedReading != nil) { return ValidationError.invalidReadDates }
        if readState == .finished && (startedReading == nil || finishedReading == nil || startedReading!.startOfDay() > finishedReading!.startOfDay()) { return ValidationError.invalidReadDates }
        return nil
    }
    
    func startReading() {
        guard readState == .toRead else { fatalError("Attempted to start a book in state \(readState)") }
        readState = .reading
        startedReading = Date()
    }
    
    func finishReading() {
        guard readState == .reading else { fatalError("Attempted to finish a book in state \(readState)") }
        readState = .finished
        finishedReading = Date()
    }
    
    static func BuildCsvExport(withLists lists: [String] = []) -> CsvExport<Book> {
        var columns = [
            CsvColumn<Book>(header: "ISBN-13", cellValue: {$0.isbn13}),
            CsvColumn<Book>(header: "Google Books ID", cellValue: {$0.googleBooksId}),
            CsvColumn<Book>(header: "Title", cellValue: {$0.title}),
            CsvColumn<Book>(header: "Authors", cellValue: {$0.authors.map{($0 as! Author).displayLastCommaFirst}.joined(separator: "; ")}),
            CsvColumn<Book>(header: "Page Count", cellValue: {$0.pageCount == nil ? nil : String(describing: $0.pageCount!)}),
            CsvColumn<Book>(header: "Publication Date", cellValue: {$0.publicationDate == nil ? nil : $0.publicationDate!.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Description", cellValue: {$0.bookDescription}),
            CsvColumn<Book>(header: "Subjects", cellValue: {$0.subjects.map{$0.name}.joined(separator: "; ")}),
            CsvColumn<Book>(header: "Started Reading", cellValue: {$0.startedReading?.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Finished Reading", cellValue: {$0.finishedReading?.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Current Page", cellValue: {$0.currentPage == nil ? nil : String(describing: $0.currentPage!)}),
            CsvColumn<Book>(header: "Notes", cellValue: {$0.notes})
        ]
        
        columns.append(contentsOf: lists.map{ listName in
            CsvColumn<Book>(header: listName, cellValue: { book in
                guard let list = book.lists.first(where: {$0.name == listName}) else { return nil }
                return String(describing: list.books.index(of: book) + 1) // we use 1-based indexes
            })
        })
        
        return CsvExport<Book>(columns: columns)
    }
    
    static var csvColumnHeaders: [String] {
        get {
            return BuildCsvExport(withLists: []).columns.map{$0.header}
        }
    }
}
