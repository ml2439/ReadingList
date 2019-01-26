import Foundation
import XCTest
@testable import ReadingList

class UpgradeActionTests: XCTestCase {
    func testActionIdsAreSequential() {
        let ids = UpgradeActionApplier().actions.map { $0.id }
        let sortedIds = ids.sorted()
        XCTAssertEqual(ids, sortedIds)
    }
}
