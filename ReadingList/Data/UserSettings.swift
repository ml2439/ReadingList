import Foundation

enum TableSortOrder: Int {
    // 0 is the default preference value.
    case byDate = 0
    case byTitle = 1
    case byAuthor = 2
    
    var displayName: String {
        switch self {
        case .byDate:
            return "By Date"
        case .byTitle:
            return "By Title"
        case .byAuthor:
            return "By Author"
        }
    }
}

class UserSettings {
    
    private static let tableSortOrderKey = "tableSortOrder"
    static var tableSortOrder: TableSortOrder {
        get {
            return TableSortOrder(rawValue: UserDefaults.standard.integer(forKey: tableSortOrderKey)) ?? .byDate
        }
        set {
            if newValue != tableSortOrder {
                UserDefaults.standard.set(newValue.rawValue, forKey: tableSortOrderKey)
                NotificationCenter.default.post(name: Notification.Name.BookSortOrderChanged, object: nil)
            }
        }
    }
    
    static func selectedBookSortDescriptors(forReadState readState: BookReadState) -> [NSSortDescriptor] {
        switch UserSettings.tableSortOrder {
        case .byTitle:
            return [NSSortDescriptor(\Book.title)]
        case .byAuthor:
            return [NSSortDescriptor(\Book.authorSort), NSSortDescriptor(\Book.title)]
        case .byDate:
            if readState == .toRead {
                return [NSSortDescriptor(\Book.sort)]
            }
            else {
                return [NSSortDescriptor(\Book.finishedReading, ascending: false), NSSortDescriptor(\Book.startedReading, ascending: false)]
            }
        }
    }

    static var sendAnalytics = UserSetting<Bool>(key: "sendAnalytics", defaultValue: true)
    static var sendCrashReports = UserSetting<Bool>(key: "sendCrashReports", defaultValue: true)
    static var useLargeTitles = UserSetting<Bool>(key: "useLargeTitles", defaultValue: true)
    // This is not always true, tip functionality predates this setting...
    static var hasEverTipped = UserSetting<Bool>(key: "hasEverTipped", defaultValue: false)
}

extension Notification.Name {
    static let BookSortOrderChanged = Notification.Name("book-sort-order-changed")
}
