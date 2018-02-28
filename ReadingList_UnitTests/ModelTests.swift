import XCTest
import Foundation
import CoreData
@testable import Reading_List

class ModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        testContainer.loadPersistentStores{ _,_ in }
    }
    
    let testContainer = NSPersistentContainer(inMemoryStoreWithName: "books")
    
    func testBookSort() {
        let maxSort = Book.maxSort(fromContext: testContainer.viewContext) ?? 0
        
        // Add two books and check sort increments for both
        let book = Book(context: testContainer.viewContext, readState: .toRead)
        book.title = "title"
        book.authors = NSOrderedSet(arrayLiteral: Author(context: testContainer.viewContext, lastName: "Lastname", firstNames: "Firstname"))
        testContainer.viewContext.saveIfChanged()
        XCTAssertEqual(maxSort + 1, book.sort!.int32)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, book.sort!.int32)
        
        let book2 = Book(context: testContainer.viewContext, readState: .toRead)
        book2.title = "title2"
        book2.authors = NSOrderedSet(arrayLiteral: Author(context: testContainer.viewContext, lastName: "Lastname", firstNames: "Firstname"))
        testContainer.viewContext.saveIfChanged()
        XCTAssertEqual(maxSort + 2, book2.sort!.int32)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, book2.sort!.int32)
        
        // Add book to .reading and check sort remains nil
        let book3 = Book(context: testContainer.viewContext, readState: .reading)
        book3.title = "title3"
        book3.authors = NSOrderedSet(arrayLiteral: Author(context: testContainer.viewContext, lastName: "Lastname", firstNames: "Firstname"))
        testContainer.viewContext.saveIfChanged()
        XCTAssertEqual(nil, book3.sort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, book2.sort!.int32)
        
        // Add book with prepopulated sort, check it is not changed
        let book4 = Book(context: testContainer.viewContext, readState: .toRead)
        book4.title = "title3"
        book4.authors = NSOrderedSet(arrayLiteral: Author(context: testContainer.viewContext, lastName: "Lastname", firstNames: "Firstname"))
        book4.sort = 12
        testContainer.viewContext.saveIfChanged()
        XCTAssertEqual(12, book4.sort)
        XCTAssertEqual(Book.maxSort(fromContext: testContainer.viewContext)!, book4.sort!.int32)
    }
    
    func testAuthorSort() {
        let book = Book(context: testContainer.viewContext, readState: .toRead)
        book.title = "title"
        book.authors = NSOrderedSet(arrayLiteral: Author(context: testContainer.viewContext, lastName: "Birkhäuser", firstNames: "Wahlöö"),
                                    Author(context: testContainer.viewContext, lastName: "Sjöwall", firstNames: "Maj"))
        testContainer.viewContext.saveIfChanged()
        
        XCTAssertEqual("birkhauser.wahloo..sjowall.maj", book.authorSort)
        XCTAssertEqual("Wahlöö Birkhäuser, Maj Sjöwall", book.authorDisplay)
    }
}
 
