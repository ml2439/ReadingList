import Foundation
import ReadingList_Foundation

extension UserSettingsCollection {
    static let sendAnalytics = UserSetting<Bool>("sendAnalytics", defaultValue: true)
    static let sendCrashReports = UserSetting<Bool>("sendCrashReports", defaultValue: true)

    /// This is not always true; tip functionality predates this setting...
    static let hasEverTipped = UserSetting<Bool>("hasEverTipped", defaultValue: false)

    /// The most recent version for which the persistent store has been successfully initialised.
    /// This is the user facing description of the version, e.g. "1.5" or "1.6.1 beta 3".
    static let mostRecentWorkingVersion = UserSetting<String?>("mostRecentWorkingVersion")

    static let lastAppliedUpgradeAction = UserSetting<Int?>("lastAppliedUpgradeAction")

    static let theme = UserSetting<Theme>("theme", defaultValue: .normal)

    static let toReadSort = UserSetting<BookSort>("toReadSortOrder", defaultValue: .custom)
    static let readingSort = UserSetting<BookSort>("readingSortOrder", defaultValue: .startDate)
    static let finishedSort = UserSetting<BookSort>("finishedSortOrder", defaultValue: .finishDate)

    static func sortSetting(for readState: BookReadState) -> UserSetting<BookSort> {
        switch readState {
        case .toRead: return toReadSort
        case .reading: return readingSort
        case .finished: return finishedSort
        }
    }

    static let addBooksToTopOfCustom = UserSetting<Bool>("addCustomBooksToTopOfCustom", defaultValue: false)

    static let appStartupCount = UserSetting<Int>("appStartupCount", defaultValue: 0)
    static let userEngagementCount = UserSetting<Int>("userEngagementCount", defaultValue: 0)
}
