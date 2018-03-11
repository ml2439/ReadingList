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
    
    static let toReadSortOrderKey = "toReadSortOrder"
    static var toReadSortOrder: TableSortOrder {
        get {
            let int = UserDefaults.standard.integer(forKey: UserSettings.toReadSortOrderKey)
            guard int != 0 else { return .customOrder } // TODO: Use old setting
            let result = TableSortOrder(rawValue: int)!
            guard result != .byStartDate && result != .byFinishDate else { fatalError("Table sort order was \(int) which is not supported") }
            return result
        }
        set {
            guard newValue != .byStartDate && newValue != .byFinishDate else { fatalError("Cannot set \(newValue.rawValue) to table sort order") }
            UserDefaults.standard.set(newValue.rawValue, forKey: UserSettings.toReadSortOrderKey)
        }
    }
    
    static func selectedBookSortDescriptors(forReadState readState: BookReadState) -> [NSSortDescriptor] {
        
        switch UserSettings.toReadSortOrder {
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

    static private var legacyTableSortOrder = UserSetting<Int?>(key: "tableSortOrder", defaultValue: nil)
    static var sendAnalytics = UserSetting<Bool>(key: "sendAnalytics", defaultValue: true)
    static var sendCrashReports = UserSetting<Bool>(key: "sendCrashReports", defaultValue: true)
    static var useLargeTitles = UserSetting<Bool>(key: "useLargeTitles", defaultValue: true)
    // This is not always true, tip functionality predates this setting...
    static var hasEverTipped = UserSetting<Bool>(key: "hasEverTipped", defaultValue: false)
}

extension Notification.Name {
    static let BookSortOrderChanged = Notification.Name("book-sort-order-changed")
}
