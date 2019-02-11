import XCTest

class Settings: XCTestCase {

    private let defaultLaunchArguments = ["--reset", "--UITests", "--UITests_PopulateData"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testExportBook() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        app.clickTab(.settings)
        app.tables.staticTexts["Import / Export"].tap()
        app.tables.staticTexts["Export"].tap()

        let cancel = app.buttons["Cancel"]
        if UIDevice.current.userInterfaceIdiom != .pad {
            XCTAssert(cancel.waitForExistence(timeout: 5))
            cancel.tap()
        }
    }

    func testSortOrders() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        app.clickTab(.settings)
        app.tables.staticTexts["Sort"].tap()

        let tables = app.tables.element(boundBy: UIDevice.current.userInterfaceIdiom == .pad ? 1 : 0)
        var sortCount = 0
        for cell in tables.children(matching: .cell).allElementsBoundByIndex {
            guard cell.exists else {
                if sortCount > 9 { return }
                fatalError("Only \(sortCount) sorts tested")
            }
            sortCount += 1
            cell.tap()
            app.clickTab(.toRead)
            app.clickTab(.finished)
            app.clickTab(.settings)
        }
    }
}
