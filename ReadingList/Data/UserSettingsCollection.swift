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

    static let toReadSortOrder = UserSetting<TableSortOrder>("toReadSortOrder", defaultValue: .customOrder)
    static let readingSortOrder = UserSetting<TableSortOrder>("readingSortOrder", defaultValue: .byStartDate)
    static let finishedSortOrder = UserSetting<TableSortOrder>("finishedSortOrder", defaultValue: .byFinishDate)

    static let addBooksToTopOfCustom = UserSetting<Bool>("addCustomBooksToTopOfCustom", defaultValue: false)

    static let appStartupCount = UserSetting<Int>("appStartupCount", defaultValue: 0)
    static let userEngagementCount = UserSetting<Int>("userEngagementCount", defaultValue: 0)
}
