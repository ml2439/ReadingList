import XCTest

class ScanBarcode: XCTestCase {

    let mockServer = MockServer()
    private let barcodeSimulationArgument = "-barcode-isbn-simulation"
    private lazy var port: UInt16 = {
        // Generate a port from the matrix of iOS versions and iPhone / iPad
        let basePort: UInt16
        if #available(iOS 12.0, *) {
            basePort = 8090
        } else if #available(iOS 11.0, *) {
            basePort = 8080
        } else {
            basePort = 8070
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            return basePort + 1
        } else {
            return basePort
        }
    }()
    private lazy var defaultLaunchArguments: [String] = {
        ["--reset", "--UITests", "-google-api-url-simulation", "http://localhost:\(self.port)"]
    }()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        try! mockServer.server.start(port)
        print("Running mock Google API on port \(self.port)")
    }

    override func tearDown() {
        super.tearDown()
        mockServer.server.stop()
    }

    private func scanBarcode(app: ReadingListApp) {
        app.clickTab(.toRead)
        app.navigationBars["To Read"].buttons["Add"].tap()
        app.sheets.buttons["Scan Barcode"].tap()
    }

    func testBarcodeScannerNormal() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        // Normal mode
        scanBarcode(app: app)
        let cancel = app.navigationBars.element(boundBy: 0).buttons["Cancel"]
        _ = cancel.waitForExistence(timeout: 5)
        cancel.tap()
    }

    func testBarcodeScannerValidIsbn() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments + [barcodeSimulationArgument, "9781781100264"]
        app.launch()

        // Valid ISBN
        scanBarcode(app: app)
        let done = app.navigationBars.element(boundBy: 0).buttons["Done"]
        _ = done.waitForExistence(timeout: 5)
        done.tap()
    }

    func testBarcodeScannerNotFoundIsbn() {
        let app = ReadingListApp()
        app.launchArguments = defaultLaunchArguments + [barcodeSimulationArgument, "9781111111111"]
        app.launch()

        // Not found ISBN
        scanBarcode(app: app)
        _ = app.alerts.element(boundBy: 0).waitForExistence(timeout: 5)
        XCTAssertEqual(app.alerts.count, 1)
        let noMatchAlert = app.alerts.element(boundBy: 0)
        XCTAssertEqual("No Exact Match", noMatchAlert.label)
        noMatchAlert.buttons["No"].tap()
        app.navigationBars.element(boundBy: 0).buttons["Cancel"].tap()

    }

    func testBarcodeScannerExistingIsbn() {
        let app = ReadingListApp()
        // The ISBN below is contained in the test data
        app.launchArguments = defaultLaunchArguments + ["--UITests_PopulateData", barcodeSimulationArgument, "9780547345666"]
        app.launch()

        // Existing ISBN
        scanBarcode(app: app)
        _ = app.alerts.element(boundBy: 0).waitForExistence(timeout: 5)
        XCTAssertEqual(app.alerts.count, 1)
        let duplicateAlert = app.alerts.element(boundBy: 0)
        XCTAssertEqual("Book Already Added", duplicateAlert.label)
        duplicateAlert.buttons["Cancel"].tap()
        app.navigationBars.element(boundBy: 0).buttons["Cancel"].tap()
    }
}
