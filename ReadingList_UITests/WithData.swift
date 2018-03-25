import XCTest

class WithData: XCTestCase {
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let app = ReadingListApplication()
        app.launchArguments.append("--UITests_PopulateData")
        app.launch()
        sleep(5)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAddManualBook() {
        let app = ReadingListApplication()
        
        app.clickTab(.toRead)
        
        let initialNumberOfCells = Int(app.tables.cells.count)
        app.clickAddButton(addMethod: .enterManually)
        
        app.tables.textFields.element(boundBy: 0).tap()
        app.typeText("The Catcher in the Rye")
        
        app.tables.staticTexts["Add Author"].tap()
        app.tables.textFields["First Name(s)"].tap()
        app.typeText("J.D.")
        app.tables.textFields["Last Name"].tap()
        app.typeText("Salinger")
        app.navigationBars.element(boundBy: 0).buttons["Add Book"].tap()
        
        app.navigationBars.element(boundBy: 0).buttons["Next"].tap()
        app.navigationBars.element(boundBy: 0).buttons["Done"].tap()
        
        sleep(1)
        XCTAssertEqual(app.tables.cells.count, initialNumberOfCells + 1)
    }
    
    func testEditBook() {
        let app = ReadingListApplication()

        app.clickTab(.toRead)
        app.tables.cells.element(boundBy: 0).tap()
        app.scrollViews.otherElements.buttons["Edit"].tap()
        
        app.tables.textFields.element(boundBy: 0).tap()
        app.typeText("changed!")
        app.navigationBars.matching(identifier: "Edit Book").buttons["Done"].tap()
    }
    
    func testDeleteBook() {
        let app = ReadingListApplication()
        
        app.clickTab(.toRead)
        let bookCount = Int(app.tables.element(boundBy: 0).cells.count)
        
        app.tables.cells.element(boundBy: 0).tap()
        app.scrollViews.otherElements.buttons["Edit"].tap()
        
        app.tables.staticTexts["Delete"].tap()
        app.sheets.buttons["Delete"].tap()
        
        sleep(1)
        XCTAssertEqual(app.tables.cells.count, bookCount - 1)
    }
    
    func testExportBook() {
        let app = ReadingListApplication()
        
        app.clickTab(.settings)
        app.tables.staticTexts["Data"].tap()
        app.tables.staticTexts["Export"].tap()
        
        if #available(iOS 11, *) {} else {
            sleep(5)
            app.collectionViews.collectionViews.buttons["Add To iCloud Drive"].tap()
            app.navigationBars["iCloud Drive"].buttons["Cancel"].tap()
        }
    }
    
    private func scanBarcode(app: ReadingListApplication, mode: ReadingListApplication.BarcodeScanSimulation) {
        app.setBarcodeSimulation(mode)
        app.clickTab(.toRead)
        
        app.navigationBars["To Read"].buttons["Add"].tap()
        app.sheets.buttons["Scan Barcode"].tap()
    }
    
    func testBarcodeScannerNormal() {
        let app = ReadingListApplication()
        
        // Normal mode
        scanBarcode(app: app, mode: .normal)
        sleep(1)
        app.navigationBars.element(boundBy: 0).buttons["Cancel"].tap()
    }
    
    func testBarcodeScannerNoPermissions() {
        let app = ReadingListApplication()
        
        // No permissions
        scanBarcode(app: app, mode: .noCameraPermissions)
        sleep(1)
        XCTAssertEqual(app.alerts.count, 1)
        let permissionAlert = app.alerts.element(boundBy: 0)
        XCTAssertEqual("Permission Required", permissionAlert.label)
        permissionAlert.buttons["Cancel"].tap()
    }
    
    func testBarcodeScannerValidIsbn() {
        let app = ReadingListApplication()
        
        // Valid ISBN
        scanBarcode(app: app, mode: .validIsbn)
        sleep(5)
        app.navigationBars.element(boundBy: 0).buttons["Done"].tap()
        
    }
    
    func testBarcodeScannerNotFoundIsbn() {
        let app = ReadingListApplication()
        
        // Not found ISBN
        scanBarcode(app: app, mode: .unfoundIsbn)
        sleep(3)
        XCTAssertEqual(app.alerts.count, 1)
        let noMatchAlert = app.alerts.element(boundBy: 0)
        XCTAssertEqual("No Exact Match", noMatchAlert.label)
        noMatchAlert.buttons["No"].tap()
        app.navigationBars.element(boundBy: 0).buttons["Cancel"].tap()
        
    }
    
    func testBarcodeScannerExistingIsbn() {
        let app = ReadingListApplication()
        
        // Existing ISBN
        scanBarcode(app: app, mode: .existingIsbn)
        sleep(1)
        XCTAssertEqual(app.alerts.count, 1)
        let duplicateAlert = app.alerts.element(boundBy: 0)
        XCTAssertEqual("Book Already Added", duplicateAlert.label)
        duplicateAlert.buttons["Cancel"].tap()
        app.navigationBars.element(boundBy: 0).buttons["Cancel"].tap()
    }
}
