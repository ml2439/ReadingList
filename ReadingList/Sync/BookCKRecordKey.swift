import Foundation
import CoreData
import CloudKit

/**
 Encapsulates the mapping between Book objects and CKRecord values, and additionally
 holds a Bitmask struct which is able to form Int32 bitmask values based on a collection
 of these BookCKRecordKey values, for use in storing keys which are pending remote updates.
 */
enum BookCKRecordKey: String { //swiftlint:disable redundant_string_enum_value
    // Note: the ordering of these cases matters. The position determines the value used when forming a bitmask
    case title = "title"
    case authors = "authors"
    case googleBooksId = "googleBooksId"
    case isbn13 = "isbn13"
    case pageCount = "pageCount"
    case publicationDate = "publicationDate"
    case bookDescription = "bookDescription"
    case coverImage = "coverImage"
    case notes = "notes"
    case currentPage = "currentPage"
    case sort = "sort"
    case startedReading = "startedReading"
    case finishedReading = "finishedReading" //swiftlint:enable redundant_string_enum_value

    static let all: [BookCKRecordKey] = [.title, .authors, .googleBooksId, .isbn13, .pageCount, .publicationDate, .bookDescription,
                                         .coverImage, .notes, .currentPage, .sort, .startedReading, .finishedReading]

    struct Bitmask: OptionSet {
        let rawValue: Int32

        static func unionAll(_ values: [Bitmask]) -> Bitmask {
            var result = Bitmask(rawValue: 0)
            for value in values {
                result.formUnion(value)
            }
            return result
        }
    }

    var bitmask: Bitmask {
        return Bitmask(rawValue: 1 << BookCKRecordKey.all.index(of: self)!)
    }

    static func from(ckRecordKey key: String) -> BookCKRecordKey? {
        return BookCKRecordKey.all.first { $0.rawValue == key }
    }

    static func from(coreDataKey: String) -> BookCKRecordKey? { //swiftlint:disable:this cyclomatic_complexity
        switch coreDataKey {
        case #keyPath(Book.title): return .title
        case #keyPath(Book.authors): return .authors
        case #keyPath(Book.coverImage): return .coverImage
        case #keyPath(Book.googleBooksId): return .googleBooksId
        case #keyPath(Book.isbn13): return .isbn13
        case #keyPath(Book.pageCount): return .pageCount
        case #keyPath(Book.publicationDate): return .publicationDate
        case #keyPath(Book.bookDescription): return .bookDescription
        case #keyPath(Book.notes): return .notes
        case #keyPath(Book.currentPage): return .currentPage
        case #keyPath(Book.sort): return .sort
        case #keyPath(Book.startedReading): return .startedReading
        case #keyPath(Book.finishedReading): return .finishedReading
        default: return nil
        }
    }

    func value(from book: Book) -> CKRecordValue? { //swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .title: return book.title as NSString
        case .googleBooksId: return book.googleBooksId as NSString?
        case .isbn13: return book.isbn13 as NSString?
        case .pageCount: return book.pageCount
        case .publicationDate: return book.publicationDate as NSDate?
        case .bookDescription: return book.bookDescription as NSString?
        case .notes: return book.notes as NSString?
        case .currentPage: return book.currentPage
        case .sort: return book.sort
        case .startedReading: return book.startedReading as NSDate?
        case .finishedReading: return book.finishedReading as NSDate?
        case .authors: return NSKeyedArchiver.archivedData(withRootObject: book.authors) as NSData
        case .coverImage:
            guard let coverImage = book.coverImage else { return nil }
            let imageFilePath = URL.temporary()
            FileManager.default.createFile(atPath: imageFilePath.path, contents: coverImage, attributes: nil)
            return CKAsset(fileURL: imageFilePath)
        }
    }

    func setValue(_ value: CKRecordValue?, for book: Book) { //swiftlint:disable:this cyclomatic_complexity
        switch self {
        case .title: book.title = value as! String
        case .googleBooksId: book.googleBooksId = value as? String
        case .isbn13: book.isbn13 = value as? String
        case .pageCount: book.pageCount = value as? NSNumber
        case .publicationDate: book.publicationDate = value as? Date
        case .bookDescription: book.bookDescription = value as? String
        case .notes: book.notes = value as? String
        case .currentPage: book.currentPage = value as? NSNumber
        case .sort: book.sort = value as? NSNumber
        case .startedReading: book.startedReading = value as? Date
        case .finishedReading: book.finishedReading = value as? Date
        case .authors:
            book.setAuthors(NSKeyedUnarchiver.unarchiveObject(with: value as! Data) as! [Author])
        case .coverImage:
            guard let imageAsset = value as? CKAsset else { book.coverImage = nil; return }
            book.coverImage = FileManager.default.contents(atPath: imageAsset.fileURL.path)
            // TODO: this doesn't work if using serverRecord during a merge
        }
    }
}

extension CKRecord {
    subscript (_ key: BookCKRecordKey) -> CKRecordValue? {
        get { return self.object(forKey: key.rawValue) }
        set { self.setObject(newValue, forKey: key.rawValue) }
    }

    func changedBookKeys() -> [BookCKRecordKey] {
        return changedKeys().compactMap({ BookCKRecordKey(rawValue: $0) })
    }
}
