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
            expectedSorts: [.toRead: .customOrder, .reading: .byStartDate, .finished: .byFinishDate]
        )
        assertSuccessfulSortMigration(
            legacyValue: 1,
            expectedSorts: [.toRead: .byTitle, .reading: .byTitle, .finished: .byTitle]
        )
        assertSuccessfulSortMigration(
            legacyValue: 2,
            expectedSorts: [.toRead: .byAuthor, .reading: .byAuthor, .finished: .byAuthor]
        )
    }

    private func assertSuccessfulSortMigration(legacyValue: Int, expectedSorts: [BookReadState: TableSortOrder]) {
        // Reset all user defaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)

        // Spoof an old version of the app
        UserDefaults.standard[.lastAppliedUpgradeAction] = 0

        let legacyTableSortOrderKey = "tableSortOrder"
        UserDefaults.standard.set(legacyValue, forKey: legacyTableSortOrderKey)

        UpgradeManager().performNecessaryUpgradeActions()
        XCTAssertEqual(TableSortOrder.byReadState, expectedSorts)
        XCTAssertGreaterThan(UserDefaults.standard[.lastAppliedUpgradeAction]!, 0)
        XCTAssertNil(UserDefaults.standard.object(forKey: legacyTableSortOrderKey))
    }
}
