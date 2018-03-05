import Foundation
import CoreData

class BookCSVImporter {
    let backgroundContext: NSManagedObjectContext
    
    init() {
        self.backgroundContext = PersistentStoreManager.container.newBackgroundContext()
    }
    
    public func startImport(fromFileAt fileLocation: URL, _ completion: @escaping (BookCSVImportResults) -> ()) {
        let parser = CSVParser(csvFileUrl: fileLocation)
        parser.delegate = BookCSVParserDelegate(context: backgroundContext, completion: completion)
        parser.begin()
    }
}

struct BookCSVImportResults {
    let success: Int
    let error: Int
    let duplicate: Int
}

fileprivate class BookCSVParserDelegate: CSVParserDelegate {
    private let context: NSManagedObjectContext
    private let onCompletion: (BookCSVImportResults) -> ()
    private var currentSort: Int32?
    private let dispatchGroup = DispatchGroup()
    private var listMappings = [String: [(bookID: NSManagedObjectID, index: Int)]]()
    private var listNames = [String]()
    
    init(context: NSManagedObjectContext, completion: @escaping (BookCSVImportResults) -> ()) {
        self.context = context
        self.onCompletion = completion
    }
    
    func headersRead(_ headers: [String]) -> Bool {
        if !headers.contains("Title") || !headers.contains("Authors") {
            return false
        }
        listNames = headers.filter{!BookCSVExport.headers.contains($0)}
        return true
    }
    
    private func createBook(_ values: [String: String]) -> Book? {
        guard let title = values["Title"] else { return nil }
        guard let authors = values["Authors"] else { return nil }
        let book = Book(context: self.context, readState: .toRead)
        book.title = title
        book.setAuthors(createAuthors(authors))
        book.googleBooksId = values["Google Books ID"]
        book.isbn13 = ISBN13(values["ISBN-13"])?.string
        book.pageCount = Int(values["Page Count"])?.nsNumber
        book.currentPage = Int(values["Current Page"])?.nsNumber
        book.notes = values["Notes"]
        book.publicationDate = Date(iso: values["Publication Date"])
        book.bookDescription = values["Description"]
        book.startedReading = Date(iso: values["Started Reading"])
        book.finishedReading = Date(iso: values["Finished Reading"])
        book.subjects = Set(createSubjects(values["Subjects"]))
        return book
    }
    
    private func createAuthors(_ authorString: String) -> [Author] {
        return authorString.components(separatedBy: ";").flatMap({$0.trimming().nilIfWhitespace()}).map({ authorString -> Author in
            if let firstCommaPos = authorString.range(of: ","), let lastName = authorString[..<firstCommaPos.lowerBound].trimming().nilIfWhitespace() {
                return Author(context: context, lastName: lastName, firstNames: authorString[firstCommaPos.upperBound...].trimming().nilIfWhitespace())
            }
            else {
                return Author(context: context, lastName: authorString, firstNames: nil)
            }
        })
    }
    
    private func createSubjects(_ subjects: String?) -> [Subject] {
        guard let subjects = subjects else { return [] }
        return subjects.components(separatedBy: ";").flatMap({$0.trimming().nilIfWhitespace()}).map({ subjectString -> Subject in
            return Subject.getOrCreate(inContext: context, withName: subjectString)
        })
    }
    
    private func populateLists() {
        for listMapping in listMappings {
            let list = List.getOrCreate(fromContext: self.context, withName: listMapping.key)
            let orderedBooks = listMapping.value.sorted(by: {$0.1 < $1.1})
                .map{context.object(with: $0.bookID) as! Book}
                .filter{!list.books.contains($0)}
            list.addBooks(NSOrderedSet(array: orderedBooks))
        }
    }
    
    private func populateCover(forBook book: Book, withGoogleID googleID: String) {
        dispatchGroup.enter()
        GoogleBooks.getCover(googleBooksId: googleID) { [unowned self] result in
            self.context.perform {
                if let data = result.value {
                    book.coverImage = data
                }
                self.dispatchGroup.leave()
            }
        }
    }
    
    func lineParseSuccess(_ values: [String: String]){
        // FUTURE: Batch save
        context.performAndWait { [unowned self] in
            // Check for duplicates
            guard Book.get(fromContext: self.context, googleBooksId: values["Google Books ID"], isbn: values["ISBN-13"]) == nil else {
                print("Duplicate book skipped")
                duplicateCount += 1; return
            }
            
            guard let newBook = createBook(values) else { invalidCount += 1; return }
            
            // FUTURE: the read state could be inferred from the dates at save time
            if newBook.finishedReading != nil {
                newBook.readState = .finished
            }
            else if newBook.startedReading != nil {
                newBook.readState = .reading
            }
            else {
                // Get the current sort value if we have not done so yet
                if currentSort == nil {
                    currentSort = Book.maxSort(fromContext: context) ?? -1
                }
                currentSort! += 1
                newBook.sort = currentSort?.nsNumber
            }
            
            // If the book is not valid, delete it
            guard newBook.isValidForUpdate() else {
                invalidCount += 1
                print("Invalid book; deleting")
                newBook.delete()
                return
            }
            successCount += 1
            
            // Record the list memberships
            for listName in listNames {
                if let listPosition = Int(values[listName]) {
                    if listMappings[listName] == nil { listMappings[listName] = [] }
                    listMappings[listName]!.append((newBook.objectID, listPosition))
                }
            }
            
            // Supplement the book with the cover image
            if let googleBookdID = newBook.googleBooksId {
                populateCover(forBook: newBook, withGoogleID: googleBookdID)
            }
        }
    }
    
    private var duplicateCount = 0
    private var invalidCount = 0
    private var successCount = 0
    
    func lineParseError() {
        invalidCount += 1
    }
    
    func completion() {
        dispatchGroup.notify(queue: .main) {
            self.context.performAndWait {
                self.populateLists()
                try! self.context.save()
            }
            self.onCompletion(BookCSVImportResults(success: self.successCount, error: self.invalidCount, duplicate: self.duplicateCount))
        }
    }
}
