import Foundation

class BookCSVExport {
    static func build(withLists lists: [String]) -> CsvExport<Book> {
        var columns = [
            CsvColumn<Book>(header: "ISBN-13", cellValue: {$0.isbn13}),
            CsvColumn<Book>(header: "Google Books ID", cellValue: {$0.googleBooksId}),
            CsvColumn<Book>(header: "Title", cellValue: {$0.title}),
            CsvColumn<Book>(header: "Authors", cellValue: {$0.authors.map {($0 as! Author).displayLastCommaFirst}.joined(separator: "; ")}),
            CsvColumn<Book>(header: "Page Count", cellValue: {$0.pageCount == nil ? nil : String(describing: $0.pageCount!)}),
            CsvColumn<Book>(header: "Publication Date",
                            cellValue: {$0.publicationDate == nil ? nil : $0.publicationDate!.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Description", cellValue: {$0.bookDescription}),
            CsvColumn<Book>(header: "Subjects", cellValue: {$0.subjects.map {$0.name}.joined(separator: "; ")}),
            CsvColumn<Book>(header: "Started Reading", cellValue: {$0.startedReading?.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Finished Reading", cellValue: {$0.finishedReading?.string(withDateFormat: "yyyy-MM-dd")}),
            CsvColumn<Book>(header: "Current Page", cellValue: {$0.currentPage == nil ? nil : String(describing: $0.currentPage!)}),
            CsvColumn<Book>(header: "Notes", cellValue: {$0.notes})
        ]

        columns.append(contentsOf: lists.map { listName in
            CsvColumn<Book>(header: listName, cellValue: { book in
                guard let list = book.lists.first(where: {$0.name == listName}) else { return nil }
                return String(describing: list.books.index(of: book) + 1) // we use 1-based indexes
            })
        })

        return CsvExport<Book>(columns: columns)
    }

    static var headers: [String] {
        return build(withLists: []).columns.map {$0.header}
    }
}
