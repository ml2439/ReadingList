import Foundation

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
    
    static var tableSortOrders: [BookReadState: TableSortOrder] {
        return [BookReadState: TableSortOrder](dictionaryLiteral:
                                                (.toRead, toReadSortOrder.value),
                                                (.reading, readingSortOrder.value),
                                                (.finished, finishedSortOrder.value))
    }

    static private var legacyTableSortOrder = UserSetting<Int?>(key: "tableSortOrder", defaultValue: nil)
    static var sendAnalytics = UserSetting<Bool>(key: "sendAnalytics", defaultValue: true)
    static var sendCrashReports = UserSetting<Bool>(key: "sendCrashReports", defaultValue: true)
    static var useLargeTitles = UserSetting<Bool>(key: "useLargeTitles", defaultValue: true)
    
    // This is not always true, tip functionality predates this setting...
    static var hasEverTipped = UserSetting<Bool>(key: "hasEverTipped", defaultValue: false)
    
    static var theme = WrappedUserSetting<Theme>(key: "theme", defaultValue: Theme.normal)

    static var toReadSortOrder = WrappedUserSetting<TableSortOrder>(key: "toReadSortOrder", defaultValue: .customOrder)
    static var readingSortOrder = WrappedUserSetting<TableSortOrder>(key: "readingSortOrder", defaultValue: .byStartDate)
    static var finishedSortOrder = WrappedUserSetting<TableSortOrder>(key: "finishedSortOrder", defaultValue: .byFinishDate)
}

extension Notification.Name {
    static let BookSortOrderChanged = Notification.Name("book-sort-order-changed")
}
