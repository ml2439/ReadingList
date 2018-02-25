import XCTest
import CoreData
@testable import Reading_List

/*
 TODO: Rewrite
class ModelMigrationTests: XCTestCase {
    
    /*
     var title: String
     var authorList: String
     var isbn13: String?
     var googleBooksId: String?
     var pageCount: NSNumber?
     var publicationDate: Date?
     var bookDescription: String?
     var coverImage: Data?
     var readState: BookReadState
     var startedReading: Date?
     var finishedReading: Date?
     var notes: String?
     var sort: NSNumber?
     var createdWhen: Date
     var subjects: NSOrderedSet
     */
    
    var storeName: String!
    var oldCoreDataStack: CoreDataStack!

    override func setUp() {
        super.setUp()
        storeName = UUID.init().uuidString
        oldCoreDataStack = CoreDataStack(momDirectoryName: "books", persistentStoreType: .sqlite, persistentStoreName: storeName, desiredMomName: "books_5")
    }

    func testMigrateBookFromV5() {
        
        let bookV5 = oldCoreDataStack.createNew(entity: "Book")
        
        let testValues: [String: Any?] = ["title": "Title here",
                                          "authorList": "Author 1, Author 2",
                                          "isbn13": "9780000000000",
                                          "googleBooksId": "QWERTY1234",
                                          "pageCount": NSNumber(value: 382),
                                          "readState": Int32(exactly: 1)]
        for testValue in testValues {
            bookV5.setValue(testValue.value, forKey: testValue.key)
        }
        try! oldCoreDataStack.managedObjectContext.save()
        
        // Initialise a new Core Data Stack, which will migrate the original store
        let coreDataStackCurrent = CoreDataStack(momDirectoryName: "books", persistentStoreType: .sqlite, persistentStoreName: storeName)
        
        let books = try! coreDataStackCurrent.managedObjectContext.fetch(NSFetchRequest(entityName: "Book"))
        XCTAssertEqual(1, books.count)
        let migratedBook = books[0] as! Book

        XCTAssertEqual(testValues["title"] as! String, migratedBook.title)
        XCTAssertEqual(testValues["readState"] as! Int32, migratedBook.readState.rawValue)
        XCTAssertEqual(testValues["pageCount"] as? NSNumber, migratedBook.pageCount)
        XCTAssertEqual(testValues["isbn13"] as! String?, migratedBook.isbn13)
        XCTAssertEqual(testValues["googleBooksId"] as! String?, migratedBook.googleBooksId)
        
        XCTAssertEqual(2, migratedBook.authors.count)
        let author1 = migratedBook.authors[0] as! Author
        let author2 = migratedBook.authors[1] as! Author
        XCTAssertEqual("Author", author1.firstNames)
        XCTAssertEqual("1", author1.lastName)
        XCTAssertEqual("Author", author2.firstNames)
        XCTAssertEqual("2", author2.lastName)
    }
    
    func testAuthorListMigration() {
        let authorLists: [String: [(String?, String)]]
            = ["": [],
               "  ": [],
               ",": [],
               " , ": [],
               "Lastname": [(nil, "Lastname")],
               "Firstname Lastname": [("Firstname", "Lastname")],
               "Firstname   Lastname": [("Firstname", "Lastname")],
               "Firstname  ,  Lastname": [(nil, "Firstname"), (nil, "Lastname")],
               "Firstname Middle Lastname": [("Firstname Middle", "Lastname")],
               "Firstname Lastname, ": [("Firstname", "Lastname")],
               "Firstname Lastname, F2 L2": [("Firstname", "Lastname"), ("F2", "L2")],
               "Firstname Lastname, F2 L2, XYZ": [("Firstname", "Lastname"), ("F2", "L2"), (nil, "XYZ")]
            ]
        for (index, authorList) in authorLists.enumerated() {
            let book = oldCoreDataStack.createNew(entity: "Book")
            book.setValue("Book \(index)", forKey: "title")
            book.setValue(NSNumber(value: index), forKey: "sort")
            book.setValue(Int32(exactly: 2), forKey: "readState")
            book.setValue(authorList.key, forKey: "authorList")
        }
        try! oldCoreDataStack.managedObjectContext.save()
        
        // Initialise a new Core Data Stack, which will migrate the original store
        let coreDataStackCurrent = CoreDataStack(momDirectoryName: "books", persistentStoreType: .sqlite, persistentStoreName: storeName)
        let fetchRequest = NSFetchRequest<Book>(entityName: "Book")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sort", ascending: true)]
        let allBooks = try! coreDataStackCurrent.managedObjectContext.fetch(fetchRequest)
        
        XCTAssertEqual(authorLists.count, allBooks.count)
        for (index, authorList) in authorLists.enumerated() {
            let book = allBooks[index]
            XCTAssertEqual(authorList.value.count, book.authors.count)
            for (authorIndex, author) in book.authors.enumerated() {
                let author = author as! Author
                XCTAssertEqual(authorList.value[authorIndex].0, author.firstNames)
                XCTAssertEqual(authorList.value[authorIndex].1, author.lastName)
            }
        }
        
    }
    
}
 */
