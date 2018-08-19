import XCTest
import Foundation
import CoreData
@testable import Reading_List

class ModelTests: XCTestCase {

    var testContainer: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        testContainer = NSPersistentContainer(inMemoryStoreWithName: "books")
        testContainer.loadPersistentStores { _, _ in }
    }

    func testBookSort() {
        let maxSort = Book.maxSort(fromContext: testContainer.viewContext) ?? 0

        // Add two books and check sort increments for both
        let book = Book(context: testContainer.viewContext, readState: .toRead)
        book.title = "title"
        book.manualBookId = UUID().uuidString
        book.setAuthors([Author(lastName: "Lastname", firstNames: "Firstname")])
        try! testContainer.viewContext.save()
        let bookSort = Int32(truncating: book.sort!)
        XCTAssertEqual(maxSort + 1, bookSort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, bookSort)

        let book2 = Book(context: testContainer.viewContext, readState: .toRead)
        book2.title = "title2"
        book2.manualBookId = UUID().uuidString
        book2.setAuthors([Author(lastName: "Lastname", firstNames: "Firstname")])
        try! testContainer.viewContext.save()
        let book2Sort = Int32(truncating: book2.sort!)
        XCTAssertEqual(maxSort + 2, book2Sort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, book2Sort)

        // Start reading book2; check it has no sort and the maxSort goes down
        book2.startReading()
        try! testContainer.viewContext.save()
        XCTAssertEqual(nil, book2.sort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, maxSort + 1)

        // Add book to .reading and check sort remains nil
        let book3 = Book(context: testContainer.viewContext, readState: .reading)
        book3.title = "title3"
        book3.manualBookId = UUID().uuidString
        book3.setAuthors([Author(lastName: "Lastname", firstNames: "Firstname")])
        try! testContainer.viewContext.save()
        XCTAssertEqual(nil, book3.sort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, maxSort + 1)

        // Add book with prepopulated sort, check it is not changed
        let book4 = Book(context: testContainer.viewContext, readState: .toRead)
        book4.title = "title3"
        book4.manualBookId = UUID().uuidString
        book4.setAuthors([Author(lastName: "Lastname", firstNames: "Firstname")])
        book4.sort = 12
        try! testContainer.viewContext.save()
        XCTAssertEqual(12, book4.sort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, Int32(truncating: book4.sort!))
    }

    func testAuthorCalculatedProperties() {
        let book = Book(context: testContainer.viewContext, readState: .toRead)
        book.title = "title"
        book.manualBookId = UUID().uuidString
        book.setAuthors([Author(lastName: "Birkhäuser", firstNames: "Wahlöö"),
                                    Author(lastName: "Sjöwall", firstNames: "Maj")])
        try! testContainer.viewContext.save()

        XCTAssertEqual("birkhauser.wahloo..sjowall.maj", book.authorSort)
        XCTAssertEqual("Wahlöö Birkhäuser, Maj Sjöwall", Author.authorDisplay(book.authors))
    }

    func testLanguageValidation() {
        let book = Book(context: testContainer.viewContext, readState: .toRead)
        book.title = "Test"
        book.setAuthors([Author(lastName: "Test", firstNames: "Author")])
        book.manualBookId = UUID().uuidString

        book.languageCode = "zz"
        XCTAssertThrowsError(try book.validateForUpdate(), "Valid language code")

        book.languageCode = "en"
        XCTAssertNoThrow(try book.validateForUpdate(), "Invalid language code")
    }

    func testIsbnValidation() {
        let book = Book(context: testContainer.viewContext, readState: .toRead)
        book.title = "Test"
        book.setAuthors([Author(lastName: "Test", firstNames: "Author")])
        book.manualBookId = UUID().uuidString

        book.isbn13 = 1234567891234
        XCTAssertThrowsError(try book.validateForUpdate(), "Valid ISBN")

        book.isbn13 = 9781786070166
        XCTAssertNoThrow(try book.validateForUpdate(), "Invalid ISBN")
    }
}
