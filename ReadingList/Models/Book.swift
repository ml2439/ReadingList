import Foundation
import CoreData

@objc(Book)
public class Book: NSManagedObject {   
    // Book Metadata
    @NSManaged var title: String
    @NSManaged var isbn13: String?
    @NSManaged var googleBooksId: String?
    @NSManaged var pageCount: NSNumber?
    @NSManaged var publicationDate: Date?
    @NSManaged var bookDescription: String?
    @NSManaged var coverImage: Data?
    @NSManaged var firstAuthorLastName: String?
    
    // Reading Information
    @NSManaged var readState: BookReadState
    @NSManaged var startedReading: Date?
    @NSManaged var finishedReading: Date?

    // Other Metadata
    @NSManaged var notes: String?
    @NSManaged var currentPage: NSNumber?
    @NSManaged var sort: NSNumber?
    @NSManaged var createdWhen: Date
    
    // Relationships
    @NSManaged var subjects: NSOrderedSet
    @NSManaged var authors: NSOrderedSet
    @NSManaged var lists: Set<List>
    
    var authorsFirstLast: String {
        get {
            return authors.map{($0 as! Author).displayFirstLast}.joined(separator: ", ")
        }
    }

/*
    These functions might be useful but don't work on iOS 9
    See https://stackoverflow.com/q/7385439/5513562

    @objc(addSubjects:)
    @NSManaged public func addSubjects(_ values: NSOrderedSet)
    
    @objc(removeSubjects:)
    @NSManaged public func removeSubjects(_ values: NSSet)
*/

}

// TODO: rename to "tag"
@objc(Subject)
public class Subject: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var books: NSSet
    
    override public func willSave() {
        super.willSave()
        if !isDeleted && books.count == 0 {
            managedObjectContext?.delete(self)
        }
    }
}

/// The availale reading progress states
@objc enum BookReadState : Int32, CustomStringConvertible {
    case reading = 1
    case toRead = 2
    case finished = 3
    
    var description: String {
        switch self{
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


extension Book {

    func populate(from readingInformation: BookReadingInformation) {
        readState = readingInformation.readState
        startedReading = readingInformation.startedReading
        finishedReading = readingInformation.finishedReading
        currentPage = readingInformation.currentPage == nil ? nil : NSNumber(integerLiteral: readingInformation.currentPage!)
    }

    func toSpotlightItem() -> SpotlightItem {
        let spotlightTitle = "\(title) - \(authorsFirstLast)"
        
        return SpotlightItem(uniqueIdentifier: objectID.uriRepresentation().absoluteString, title: spotlightTitle, description: bookDescription, thumbnailImageData: coverImage)
    }
    
    func transistionToReading(log: Bool = true) {
        let reading = BookReadingInformation(readState: .reading, startedWhen: Date(), finishedWhen: nil, currentPage: nil)
        updateReadState(with: reading, log: log)
    }
    
    func transistionToFinished(log: Bool = true) {
        let finished = BookReadingInformation(readState: .finished, startedWhen: self.startedReading!, finishedWhen: Date(), currentPage: nil)
        updateReadState(with: finished, log: log)
    }
    
    private func updateReadState(with readingInformation: BookReadingInformation, log: Bool) {
        appDelegate.booksStore.update(book: self, withReadingInformation: readingInformation)
        if log {
            UserEngagement.logEvent(.transitionReadState)
            UserEngagement.onReviewTrigger()
        }
    }
    
    func delete(log: Bool = true) {
        appDelegate.booksStore.deleteBook(self)
        if log {
            UserEngagement.logEvent(.deleteBook)
        }
    }
    
    static func BuildCsvExport(withLists lists: [String]) -> CsvExport<Book> {
        var columns = [
            CsvColumn<Book>(header: "ISBN-13", cellValue: {$0.isbn13}),
            CsvColumn<Book>(header: "Google Books ID", cellValue: {$0.googleBooksId}),
            CsvColumn<Book>(header: "Title", cellValue: {$0.title}),
            CsvColumn<Book>(header: "Authors", cellValue: {$0.authors.map{($0 as! Author).displayLastCommaFirst}.joined(separator: "; ")}),
            CsvColumn<Book>(header: "Page Count", cellValue: {$0.pageCount == nil ? nil : String(describing: $0.pageCount!)}),
            CsvColumn<Book>(header: "Publication Date", cellValue: {$0.publicationDate == nil ? nil : $0.publicationDate!.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Description", cellValue: {$0.bookDescription}),
            CsvColumn<Book>(header: "Subjects", cellValue: {$0.subjects.map{($0 as! Subject).name}.joined(separator: "; ")}),
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


/// A mutable, non-persistent representation of the metadata fields of a Book object.
/// Useful for maintaining in-creation books, or books being edited.
// TODO: Not convinced that this class is good.
class BookMetadata {
    let googleBooksId: String?
    var title: String?
    var authors = [(firstNames: String?, lastName: String)]()
    var subjects = [String]()
    var pageCount: Int?
    var publicationDate: Date?
    var bookDescription: String?
    var isbn13: String?
    var coverImage: Data?
    //var lists = [(listName: String, bookIndex: Int)]()
    
    init(googleBooksId: String? = nil) {
        self.googleBooksId = googleBooksId
    }
    
    func isValid() -> Bool {
        return title?.isEmptyOrWhitespace == false && authors.count >= 1
    }
    
    init(book: Book) {
        self.title = book.title
        self.authors = book.authors.map{
            let author = $0 as! Author
            return (author.firstNames, author.lastName)
        }
        self.bookDescription = book.bookDescription
        self.pageCount = book.pageCount as? Int
        self.publicationDate = book.publicationDate
        self.coverImage = book.coverImage
        self.isbn13 = book.isbn13
        self.googleBooksId = book.googleBooksId
        self.subjects = book.subjects.map{($0 as! Subject).name}
    }
    
    // TODO: This definitely seems like the wrong place for this function
    static func csvImport(csvData: [String: String]) -> (BookMetadata, BookReadingInformation, notes: String?) {
        
        let bookMetadata = BookMetadata(googleBooksId: csvData["Google Books ID"]?.nilIfWhitespace())
        bookMetadata.title = csvData["Title"]?.nilIfWhitespace()
        if let authorText = csvData["Authors"]?.nilIfWhitespace() {
            bookMetadata.authors = authorText.components(separatedBy: ";")
                .flatMap{$0.trimming().nilIfWhitespace()}
                .map{
                    if let firstCommaPos = $0.range(of: ","),
                        let lastName = $0[..<firstCommaPos.lowerBound].trimming().nilIfWhitespace()  {
                        return ($0[firstCommaPos.upperBound...].trimming().nilIfWhitespace(), lastName)
                    }
                    else {
                        return (nil, $0)
                    }
                }
        }
        else {
            bookMetadata.authors = []
        }
        bookMetadata.isbn13 = Isbn13.tryParse(inputString: csvData["ISBN-13"])
        bookMetadata.pageCount = csvData["Page Count"] == nil ? nil : Int(csvData["Page Count"]!)
        bookMetadata.publicationDate = csvData["Publication Date"] == nil ? nil : Date(iso: csvData["Publication Date"]!)
        bookMetadata.bookDescription = csvData["Description"]?.nilIfWhitespace()
        bookMetadata.subjects = csvData["Subjects"]?.components(separatedBy: ";").flatMap{$0.trimming().nilIfWhitespace()} ?? []
        
        let startedReading = Date(iso: csvData["Started Reading"])
        let finishedReading = Date(iso: csvData["Finished Reading"])
        let currentPage = csvData["Current Page"] == nil ? nil : Int(string: csvData["Current Page"]!)

        let readingInformation: BookReadingInformation
        if startedReading != nil && finishedReading != nil {
            readingInformation = BookReadingInformation.finished(started: startedReading!, finished: finishedReading!)
        }
        else if startedReading != nil && finishedReading == nil {
            readingInformation = BookReadingInformation.reading(started: startedReading!, currentPage: currentPage)
        }
        else {
            readingInformation = BookReadingInformation.toRead()
        }
        
        let notes = csvData["Notes"]?.isEmptyOrWhitespace == false ? csvData["Notes"] : nil
        return (bookMetadata, readingInformation, notes)
    }
}

/// A mutable, non-persistent representation of a the reading status of a Book object.
/// Useful for maintaining in-creation books, or books being edited.
class BookReadingInformation {
    // TODO: consider create class heirachy with non-optional Dates where appropriate
    
    let readState: BookReadState
    let startedReading: Date?
    let finishedReading: Date?
    let currentPage: Int?
    
    /// Will only populate the start date if started; will only populate the finished date if finished.
    /// Otherwise, dates are set to nil.
    init(readState: BookReadState, startedWhen: Date?, finishedWhen: Date?, currentPage: Int?) {
        self.readState = readState
        switch readState {
        case .toRead:
            self.startedReading = nil
            self.finishedReading = nil
            self.currentPage = nil
        case .reading:
            self.startedReading = startedWhen!
            self.finishedReading = nil
            self.currentPage = currentPage
        case .finished:
            self.startedReading = startedWhen!
            self.finishedReading = finishedWhen!
            self.currentPage = nil
        }
    }
    
    static func toRead() -> BookReadingInformation {
        return BookReadingInformation(readState: .toRead, startedWhen: nil, finishedWhen: nil, currentPage: nil)
    }
    
    static func reading(started: Date, currentPage: Int?) -> BookReadingInformation {
        return BookReadingInformation(readState: .reading, startedWhen: started, finishedWhen: nil, currentPage: currentPage)
    }
    
    static func finished(started: Date, finished: Date) -> BookReadingInformation {
        return BookReadingInformation(readState: .finished, startedWhen: started, finishedWhen: finished, currentPage: nil)
    }
}


