import XCTest

class Screenshots: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        let app = ReadingListApplication()
        setupSnapshot(app)
        app.launchArguments.append(contentsOf: ["--UITests_PopulateData", "--UITests_FixedBarcodeScanImage", "--UITests_PrettyStatusBar", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXL"])
        app.launch()
        sleep(5)
        app.setBarcodeSimulation(.normal)
    }
    
    func testSnapshot() {
        let app = ReadingListApplication()
        app.clickTab(.toRead)
        
        let isIpad = app.navigationBars.count == 2
        if isIpad {
            app.tables.cells.element(boundBy: 2).tap()
        }

        snapshot("0_ToReadList")
        app.clickTab(.finished)
        app.tables.staticTexts["Finished"].swipeUp()
        app.tables.staticTexts["The Color Purple"].tap()
        snapshot("1_BookDetails")
        
        if !isIpad {
            // go back
            app.navigationBars["The Color Purple"].buttons["Finished"].tap()
        }
        if isIpad {
            app.tables.staticTexts["The Great Gatsby"].tap()
            app.tables.staticTexts["Finished"].swipeDown()
        }
        app.navigationBars["Finished"].buttons["Add"].tap()
        app.sheets["Add New Book"].buttons["Scan Barcode"].tap()
        snapshot("2_ScanBarcode")
        
        app.navigationBars["Scan Barcode"].buttons["Cancel"].tap()
        
        app.tabBars.buttons["Finished"].tap()
        app.tables.element(boundBy: 0).swipeDown()
        
        let yourLibrarySearchField = app.searchFields["Your Library"]
        yourLibrarySearchField.tap()
        yourLibrarySearchField.typeText("Orwell")
        app.buttons["Done"].tap()
        
        if isIpad {
            app.tables.staticTexts["1984"].tap()
        }

        snapshot("3_SearchFinished")
        
    }
}



