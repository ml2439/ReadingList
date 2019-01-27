import Foundation

class ReadingListError {
    static let Domain = "com.andrewbennet.readinglist"

    enum Code: Int {
        case missingNavigationController = 1
        case invalidMigration = 2
        case noPreviousStoreVersionRecorded = 3
    }
}

extension NSError {
    convenience init(code: ReadingListError.Code, userInfo: [String: Any]? = nil) {
        self.init(domain: ReadingListError.Domain, code: code.rawValue, userInfo: userInfo)
    }
}
