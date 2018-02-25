import XCTest
import Foundation
import SwiftyJSON
import CoreData
import Firebase
@testable import Reading_List

class UnitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    static func days(_ count: Int) -> DateComponents {
        var component = DateComponents()
        component.day = count
        return component
    }
    
    private let yesterday = Date.startOfToday().date(byAdding: UnitTests.days(-1))!
    private let today = Date.startOfToday()
    private let tomorrow = Date.startOfToday().date(byAdding: UnitTests.days(1))!
    
    var currentTestBook = 0
    
    /*
    /// Gets a fully populated BookMetadata object. Increments the ISBN by 1 each time.
    private func getTestBookMetadata() -> BookMetadata {
        currentTestBook += 1
        let testBookMetadata = BookMetadata(googleBooksId: "ABC123\(currentTestBook)")
        testBookMetadata.title = "Test Book Title \(currentTestBook)"
        testBookMetadata.authors = [(firstNames: "A", lastName: "Lastname \(currentTestBook)"),
                                    (firstNames: "Author 2", lastName: "Lastname \(currentTestBook)"),
                                    (firstNames: nil, lastName: "Lastname \(currentTestBook)")]
        testBookMetadata.bookDescription = "Test Book Description \(currentTestBook)"
        testBookMetadata.isbn13 = "1234567890\(String(format: "%03d", currentTestBook))"
        testBookMetadata.pageCount = 100 + currentTestBook
        testBookMetadata.publicationDate = Date(timeIntervalSince1970: 1488926352)
        return testBookMetadata
    }
    
    func testBookMetadataPopulates() {
        let testBookMetadata = getTestBookMetadata()
        let readingInformation = BookReadingInformation.finished(started: yesterday, finished: today)
        let readingNotes = "An interesting book..."
        
        // Create the book
        let book = booksStore.create(from: testBookMetadata, readingInformation: readingInformation, readingNotes: readingNotes)
        
        // Test that the metadata is all the same
        XCTAssertEqual(testBookMetadata.googleBooksId, book.googleBooksId)
        XCTAssertEqual(testBookMetadata.title, book.title)
        XCTAssertEqual(testBookMetadata.authors.count, book.authors.count)
        for (index, authorDetails) in testBookMetadata.authors.enumerated() {
            let author = book.authors[index] as! Author
            XCTAssertEqual(authorDetails.firstNames, author.firstNames)
            XCTAssertEqual(authorDetails.lastName, author.lastName)
        }
        XCTAssertEqual(testBookMetadata.bookDescription, book.bookDescription)
        XCTAssertEqual(testBookMetadata.isbn13, book.isbn13)
        XCTAssertEqual(testBookMetadata.pageCount, book.pageCount as? Int)
        XCTAssertEqual(testBookMetadata.publicationDate, book.publicationDate)
        XCTAssertEqual(readingInformation.readState, book.readState)
        XCTAssertEqual(readingInformation.startedReading, book.startedReading)
        XCTAssertEqual(readingInformation.finishedReading, book.finishedReading)
        XCTAssertEqual(readingNotes, book.notes)
    }
    
    func testReadingNotesClear() {
        let testBookMetadata = getTestBookMetadata()
        let readingInformation = BookReadingInformation.toRead()
        let readingNotes = "An interesting book (2)..."
        
        // Create the book
        let book = booksStore.create(from: testBookMetadata, readingInformation: readingInformation, readingNotes: readingNotes)
        
        // Try some updates which should not affect the notes field first; check that the notes are still there
        booksStore.update(book: book, withMetadata: testBookMetadata)
        XCTAssertEqual(readingNotes, book.notes)
        
        booksStore.update(book: book, withReadingInformation: readingInformation)
        XCTAssertEqual(readingNotes, book.notes)
        
        // Now edit the notes field
        let newNotes = "edited"
        booksStore.update(book: book, withReadingInformation: readingInformation, readingNotes: newNotes)
        XCTAssertEqual(newNotes, book.notes)
        booksStore.update(book: book, withReadingInformation: readingInformation, readingNotes: nil)
        XCTAssertNil(book.notes)
        
    }
    
*/
}
 
