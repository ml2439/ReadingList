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
}
