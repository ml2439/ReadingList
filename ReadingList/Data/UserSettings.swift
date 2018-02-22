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
    
    // FUTURE: The predicates probably shouldn't be stored in this class
    static var selectedSortOrder: [NSSortDescriptor] {
        get { return SortOrders[UserSettings.tableSortOrder]! }
    }
    
    private static let SortOrders = [TableSortOrder.byDate: [NSSortDescriptor(\Book.readState),
                                                             NSSortDescriptor("sort"),
                                                             NSSortDescriptor(\Book.finishedReading),
                                                             NSSortDescriptor(\Book.startedReading)],
                                     TableSortOrder.byTitle: [NSSortDescriptor(\Book.readState),
                                                              NSSortDescriptor(\Book.title)],
                                     TableSortOrder.byAuthor: [NSSortDescriptor(\Book.readState),
                                                               NSSortDescriptor(\Book.firstAuthorLastName)]]

    static var sendAnalytics = UserSetting<Bool>(key: "sendAnalytics", defaultValue: true)
    static var sendCrashReports = UserSetting<Bool>(key: "sendCrashReports", defaultValue: true)
    static var useLargeTitles = UserSetting<Bool>(key: "useLargeTitles", defaultValue: true)
    // This is not always true, tip functionality predates this setting...
    static var hasEverTipped = UserSetting<Bool>(key: "hasEverTipped", defaultValue: false)
}

extension Notification.Name {
    static let BookSortOrderChanged = Notification.Name("book-sort-order-changed")
}
