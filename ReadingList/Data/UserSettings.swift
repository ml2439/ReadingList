import Foundation
import ReadingList_Foundation

enum TableSortOrder: Int {
    case customOrder = 1
    case byStartDate = 2
    case byFinishDate = 3
    case byTitle = 4
    case byAuthor = 5

    var displayName: String {
        switch self {
        case .customOrder: return "Custom"
        case .byStartDate: return "By Start Date"
        case .byFinishDate: return "By Finish Date"
        case .byTitle: return "By Title"
        case .byAuthor: return "By Author"
        }
    }
}

class UserSettings {

    static func selectedBookSortDescriptors(forReadState readState: BookReadState) -> [NSSortDescriptor] {
        switch UserSettings.tableSortOrders[readState]! {
        case .byTitle:
            return [NSSortDescriptor(\Book.title)]
        case .byAuthor:
            return [NSSortDescriptor(\Book.authorSort), NSSortDescriptor(\Book.title)]
        case .byStartDate:
            return [NSSortDescriptor(\Book.startedReading, ascending: false)]
        case .byFinishDate:
            return [NSSortDescriptor(\Book.finishedReading, ascending: false), NSSortDescriptor(\Book.startedReading, ascending: false)]
        case .customOrder:
            return [NSSortDescriptor(\Book.sort)]
        }
    }

    static func defaultSortOrder(forReadState readState: BookReadState) -> TableSortOrder {
        /*
         Legacy sort orders:
         case byDate = 0; case byTitle = 1; case byAuthor = 2
        */
        let legacySortOrder = UserDefaults.standard.integer(forKey: "tableSortOrder")
        if legacySortOrder == 1 { return .byTitle }
        if legacySortOrder == 2 { return .byAuthor }
        switch readState {
        case .toRead: return .customOrder
        case .reading: return .byStartDate
        case .finished: return .byFinishDate
        }
    }

    static var tableSortOrders: [BookReadState: TableSortOrder] {
        return [BookReadState: TableSortOrder](dictionaryLiteral: (.toRead, toReadSortOrder.value), (.reading, readingSortOrder.value), (.finished, finishedSortOrder.value))
    }

    static var sendAnalytics = UserSetting<Bool>(key: "sendAnalytics", defaultValue: true)
    static var sendCrashReports = UserSetting<Bool>(key: "sendCrashReports", defaultValue: true)

    /// This is not always true; tip functionality predates this setting...
    static var hasEverTipped = UserSetting<Bool>(key: "hasEverTipped", defaultValue: false)

    /// The most recent version for which the persistent store has been successfully initialised.
    /// This is the user facing description of the version, e.g. "1.5" or "1.6.1 beta 3".
    static var mostRecentWorkingVersion = UserSetting<String?>(key: "mostRecentWorkingVersion", defaultValue: nil)

    static var theme = WrappedUserSetting<Theme>(key: "theme", defaultValue: Theme.normal)

    static var toReadSortOrder = WrappedUserSetting<TableSortOrder>(key: "toReadSortOrder", defaultValue: defaultSortOrder(forReadState: .toRead))
    static var readingSortOrder = WrappedUserSetting<TableSortOrder>(key: "readingSortOrder", defaultValue: defaultSortOrder(forReadState: .reading))
    static var finishedSortOrder = WrappedUserSetting<TableSortOrder>(key: "finishedSortOrder", defaultValue: defaultSortOrder(forReadState: .finished))
}

extension Notification.Name {
    static let BookSortOrderChanged = Notification.Name("book-sort-order-changed")
}
