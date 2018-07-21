import Foundation
import CoreData
import Promises
import ReadingList_Foundation

class BookCSVImporter {
    let context: NSManagedObjectContext

    private var currentSort: Int32?
    private var coverDownloadPromises = [Promise<Void>]()
    private var listMappings = [String: [(bookID: NSManagedObjectID, index: Int)]]()
    private var listNames = [String]()

    required init() {
        context = PersistentStoreManager.container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }

    func importBooks(includeImages: Bool = true, from file: URL) -> Promise<BookCSVImportResults> {
        return Promise<BookCSVImportResults> { fulfill, reject in
            var results = BookCSVImportResults()

            TinyCsvParser().didReadRowCellValuesByHeaders { rowValues in
                guard let book = self.createBook(in: self.context, rowValues) else {
                    results.error += 1
                    return
                }

                // If the book is not valid, delete it
                guard book.isValidForUpdate() else {
                    results.error += 1
                    book.delete()
                    return
                }

                // Record the list memberships
                for listName in self.listNames {
                    if let listPosition = Int(rowValues[listName]) {
                        if self.listMappings[listName] == nil { self.listMappings[listName] = [] }
                        self.listMappings[listName]!.append((book.objectID, listPosition))
                    }
                }

                // Supplement the book with the cover image
                if includeImages, let googleBookdID = book.googleBooksId {
                    self.populateCover(forBook: book, withGoogleID: googleBookdID)
                }

                results.success += 1
            }.didFinishFile {
                all(self.coverDownloadPromises)
                    .always {
                        self.context.performAndWait {
                            self.populateLists()
                            self.context.saveAndLogIfErrored()
                        }
                        fulfill(results)
                    }
            }.didError(reject) {
                reject($0)
            }.parseFile(at: file)
        }
    }

    private func createBook(in context: NSManagedObjectContext, _ values: [String: String]) -> Book? {
        guard let title = values["Title"] else { return nil }
        guard let authors = values["Authors"] else { return nil }
        let book = Book(context: context, readState: .toRead)
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
        book.rating = Int(values["Rating"])?.nsNumber
        book.languageCode = values["Language Code"]

        if book.finishedReading != nil {
            book.readState = .finished
        } else if book.startedReading != nil {
            book.readState = .reading
        } else {
            // Get the current sort value if we have not done so yet
            if currentSort == nil {
                currentSort = Book.maxSort(fromContext: context) ?? -1
            }
            currentSort! += 1
            book.sort = currentSort?.nsNumber
        }

        return book
    }

    private func createAuthors(_ authorString: String) -> [Author] {
        return authorString.components(separatedBy: ";").compactMap {
            guard let authorString = $0.trimming().nilIfWhitespace() else { return nil }
            if let firstCommaPos = authorString.range(of: ","), let lastName = authorString[..<firstCommaPos.lowerBound].trimming().nilIfWhitespace() {
                return Author(lastName: lastName, firstNames: authorString[firstCommaPos.upperBound...].trimming().nilIfWhitespace())
            } else {
                return Author(lastName: authorString, firstNames: nil)
            }
        }
    }

    private func createSubjects(_ subjects: String?) -> [Subject] {
        guard let subjects = subjects else { return [] }
        return subjects.components(separatedBy: ";").compactMap {
            guard let subjectString = $0.trimming().nilIfWhitespace() else { return nil }
            return Subject.getOrCreate(inContext: context, withName: subjectString)
        }
    }

    private func populateLists() {
        for listMapping in listMappings {
            let list = List.getOrCreate(fromContext: self.context, withName: listMapping.key)
            let orderedBooks = listMapping.value.sorted { $0.1 < $1.1 }
                .map { context.object(with: $0.bookID) as! Book }
                .filter { !list.books.contains($0) }
            list.addBooks(NSOrderedSet(array: orderedBooks))
        }
    }

    private func populateCover(forBook book: Book, withGoogleID googleID: String) {
        coverDownloadPromises.append(GoogleBooks.getCover(googleBooksId: googleID)
            .then { data -> Void in
                self.context.perform {
                    book.coverImage = data
                }
                return
            }
        )
    }
}

struct BookCSVImportResults {
    var success = 0
    var error = 0
    var duplicate = 0
}
