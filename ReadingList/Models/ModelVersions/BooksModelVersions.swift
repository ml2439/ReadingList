import Foundation
import CoreData

enum BooksModelVersion: String {
    case version5 = "books_5"
    case version6 = "books_6"
    case version7 = "books_7"
    case version8 = "books_8"
    case version9 = "books_9"
    case version10 = "books_10"
    case version11 = "books_11"
    case version12 = "books_12"
    case version13 = "books_13"
}

extension BooksModelVersion: ModelVersion {

    static var orderedModelVersions: [BooksModelVersion] {
        return [.version5, .version6, .version7, .version8, .version9, .version10, .version11, .version12, .version13]
    }

    var name: String { return rawValue }
    var modelBundle: Bundle { return Bundle(for: Book.self) }
    var modelDirectoryName: String { return "books.momd" }
}
