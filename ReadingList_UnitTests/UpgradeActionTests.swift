import Foundation
import XCTest
@testable import ReadingList
import ReadingList_Foundation

class UpgradeActionTests: XCTestCase {
    func testActionIdsAreSequential() {
        let ids = UpgradeManager().actions.map { $0.id }
        let sortedIds = ids.sorted()
        XCTAssertEqual(ids, sortedIds)
    }

    func testMigrationOfTableSortOrder() {
        // Legacy sort orders: byDate = 0; byTitle = 1; byAuthor = 2
        assertSuccessfulSortMigration(
            legacyValue: 0,
            expectedSorts: [.toRead: .custom, .reading: .startDate, .finished: .finishDate]
        )
        assertSuccessfulSortMigration(
            legacyValue: 1,
            expectedSorts: [.toRead: .title, .reading: .title, .finished: .title]
        )
        assertSuccessfulSortMigration(
            legacyValue: 2,
            expectedSorts: [.toRead: .author, .reading: .author, .finished: .author]
        )
    }

    private func assertSuccessfulSortMigration(legacyValue: Int, expectedSorts: [BookReadState: BookSort]) {
        // Reset all user defaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)

        // Spoof an old version of the app
        UserDefaults.standard[.lastAppliedUpgradeAction] = 0

        let legacyTableSortOrderKey = "tableSortOrder"
        UserDefaults.standard.set(legacyValue, forKey: legacyTableSortOrderKey)

        UpgradeManager().performNecessaryUpgradeActions()
        for kvp in expectedSorts {
            XCTAssertEqual(UserDefaults.standard[UserSettingsCollection.sortSetting(for: kvp.key)], kvp.value)
        }
        XCTAssertGreaterThan(UserDefaults.standard[.lastAppliedUpgradeAction]!, 0)
        XCTAssertNil(UserDefaults.standard.object(forKey: legacyTableSortOrderKey))
    }
}
