import Foundation
import SwiftyJSON
import CHCSVParser
import CoreData

class CsvImporter: NSObject, CHCSVParserDelegate {
    
    private var erroredLineIndexes = [Int]()
    private var linesSuccessfullyReadCount = 0
    
    /// First argument is the line index, second argument is the cell values by header strings
    private let lineParseSuccessHandler: ([String: String]) -> Void
    private let lineParseErrorHandler: () -> ()
    
    private let completionHandler: () -> Void
    
    /// Argument is the headers in order they were read
    private let headersReadHandler: ([String]) -> Void
    
    private var isFirstRow = true
    private var currentRowIsErrored = false
    private var currentRow = [String: String]()
    private var headersByFieldIndex = [Int: String]()
    private let parser: CHCSVParser!
    
    init(csvFileUrl: URL, headersReadHandler: @escaping ([String]) -> Void, lineParseSuccessHandler: @escaping ([String: String]) -> Void,
         lineParseErrorHandler: @escaping () -> (), completionHandler: @escaping () -> ()) {
        parser = CHCSVParser(contentsOfCSVURL: csvFileUrl)
        parser.sanitizesFields = true
        parser.recognizesBackslashesAsEscapes = true
        parser.trimsWhitespace = true
        parser.recognizesComments = true
        
        self.headersReadHandler = headersReadHandler
        self.lineParseSuccessHandler = lineParseSuccessHandler
        self.lineParseErrorHandler = lineParseErrorHandler
        self.completionHandler = completionHandler
        super.init()
        
        parser.delegate = self
    }
    
    func parse() {
        parser.parse()
    }
    
    func parser(_ parser: CHCSVParser!, didReadField field: String!, at fieldIndex: Int) {
        if isFirstRow {
            headersByFieldIndex[fieldIndex] = field
        }
        else {
            guard let currentHeader = headersByFieldIndex[fieldIndex] else { currentRowIsErrored = true; return }
            currentRow[currentHeader] = field
        }
    }
    
    func parser(_ parser: CHCSVParser!, didEndLine recordNumber: UInt) {
        if isFirstRow {
            headersReadHandler(headersByFieldIndex.map{$0.value})
            isFirstRow = false
            return
        }
        if currentRowIsErrored {
            lineParseErrorHandler()
        }
        else {
            lineParseSuccessHandler(currentRow)
        }
    }
    
    func parser(_ parser: CHCSVParser!, didBeginLine recordNumber: UInt) {
        currentRow.removeAll(keepingCapacity: true)
        currentRowIsErrored = false
    }
    
    func parserDidEndDocument(_ parser: CHCSVParser!) {
        completionHandler()
    }
}

class BookImporter {
    
    private var importer: CsvImporter!
    private let fileUrl: URL
    private let callback: (Int, Int, Int) -> Void
    private let missingHeadersCallback: () -> ()
    private let supplementBookCallback: ((Book, DispatchGroup) -> ())?
    
    private var duplicateBookCount = 0
    private var importedBookCount = 0
    private var invalidCount = 0
    
    private var sortIndex = -1
    private var supplementBookCover: Bool
    
    // Keep track of the potentially numerous calls
    private let dispatchGroup = DispatchGroup()
    
    // The default headers - not including any list names
    private let defaultHeaders = Book.BuildCsvExport(withLists: []).headers()
    
    // List mappings
    private var listMappings = [String: [(bookId: NSManagedObjectID, index: Int)]]()
    
    init(csvFileUrl: URL, supplementBookCover: Bool = true, missingHeadersCallback: @escaping () -> Void,
         supplementBookCallback: ((Book, DispatchGroup) -> Void)? = nil, callback: @escaping (Int, Int, Int) -> Void) {
        self.fileUrl = csvFileUrl
        self.callback = callback
        self.supplementBookCover = supplementBookCover
        self.supplementBookCallback = supplementBookCallback
        self.missingHeadersCallback = missingHeadersCallback
    }
    
    func StartImport() {
        importer = CsvImporter(csvFileUrl: self.fileUrl, headersReadHandler: onHeadersRead, lineParseSuccessHandler: onLineReadSuccess, lineParseErrorHandler: onLineReadError, completionHandler: onCompletion)
        sortIndex = appDelegate.booksStore.maxSort() ?? -1
        importer.parse()
    }
    
    func onHeadersRead(headers: [String]) {
        if !headers.contains("Title") || !headers.contains("Author") {
            missingHeadersCallback()
        }
        let extraHeaders = headers.map{$0.trimming()}.filter{!defaultHeaders.contains($0)}
        for headerName in extraHeaders {
            // create all the lists which should exist
            appDelegate.booksStore.getOrCreateList(withName: headerName)
        }
    }
    
    func onCompletion() {
        dispatchGroup.notify(queue: .main) { [unowned self] in
            for listMapping in self.listMappings {
                let list = appDelegate.booksStore.getOrCreateList(withName: listMapping.key)
                let orderedBooks = listMapping.value.sorted(by: {$0.1 < $1.1})
                    .map{appDelegate.booksStore.managedObjectContext.object(with: $0.bookId) as! Book}
                    .filter{!list.books.contains($0)}
                list.books = NSOrderedSet(array: list.booksArray + orderedBooks)
                appDelegate.booksStore.save()
            }
            
            self.callback(self.importedBookCount, self.duplicateBookCount, self.invalidCount)
        }
    }
    
    func onLineReadSuccess(cellValues: [String: String]) {
        let parsedData = BookMetadata.csvImport(csvData: cellValues)
        
        // Check for invalid data, OR that we are supplementing metadata
        guard parsedData.0.isValid() else {
            invalidCount += 1
            return
        }
        
        // Check for duplicates
        guard appDelegate.booksStore.getIfExists(googleBooksId: parsedData.0.googleBooksId, isbn: parsedData.0.isbn13) == nil else {
            duplicateBookCount += 1
            return
        }
        
        // Increment the sort index if this is a ToRead book.
        let specifiedSort: Int?
        if parsedData.1.readState == .toRead {
            sortIndex += 1
            specifiedSort = sortIndex
        }
        else {
            specifiedSort = nil
        }
        
        func recordListMembership(bookId: NSManagedObjectID) {
            for listEntry in cellValues.filter({!defaultHeaders.contains($0.key.trimming())}) {//.flatMap{ (key: String, value: String) -> (String, Int)? in
                guard let bookPosition = Int(listEntry.value) else { continue }
                if listMappings[listEntry.0] == nil { listMappings[listEntry.0] = [] }
                listMappings[listEntry.0]!.append((bookId, bookPosition))
            }
        }

        dispatchGroup.enter()
        
        if supplementBookCover {
            BookImporter.supplementBook(parsedData.0) { [unowned self] in
                let book = appDelegate.booksStore.create(from: parsedData.0, readingInformation: parsedData.1, bookSort: specifiedSort, readingNotes: parsedData.2)
                
                recordListMembership(bookId: book.objectID)
                self.supplementBookCallback?(book, self.dispatchGroup)
                self.importedBookCount += 1
                self.dispatchGroup.leave()
            }
        }
        else {
            let book = appDelegate.booksStore.create(from: parsedData.0, readingInformation: parsedData.1, bookSort: specifiedSort, readingNotes: parsedData.2)
            recordListMembership(bookId: book.objectID)
            importedBookCount += 1
            dispatchGroup.leave()
        }
    }
    
    func onLineReadError() {
        invalidCount += 1
    }

    /// Callback is run on the main thread
    static func supplementBook(_ bookMetadata: BookMetadata, callback: @escaping () -> Void) {
        
        func getCoverCallback(coverResult: Result<Data>) {
            if coverResult.isSuccess {
                bookMetadata.coverImage = coverResult.value!
            }
            DispatchQueue.main.async {
                callback()
            }
        }
        
        // GoogleBooks ID takes priority over ISBN.
        if let googleBookdId = bookMetadata.googleBooksId {
            GoogleBooks.getCover(googleBooksId: googleBookdId, callback: getCoverCallback)
        }
        // but we'll try the ISBN is there was no Google Books ID
        // TODO: would be nice to supplement with GBID too
        else if let isbn = bookMetadata.isbn13 {
            GoogleBooks.getCover(isbn: isbn, callback: getCoverCallback)
        }
        else {
            callback()
        }
    }
}
