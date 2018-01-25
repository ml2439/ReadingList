//
//  books_Snapshot.swift
//  books
//
//  Created by Andrew Bennet on 20/03/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

import XCTest

class books_Snapshot: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        let app = ReadingListApplication()
        setupSnapshot(app)
        app.launchArguments.append("--UITests_PopulateData")
        app.launch()
        
        // There's a weird glitch with the search bar when books are first added. Restart the app the fix it.
        app.terminate()
        app.launch()
        app.setBarcodeSimulation(.normal)
        app.toggleBarcodeScanFixedImage()
        app.togglePrettyStatusBar()
    }
    
    override func tearDown() {
        let app = ReadingListApplication()
        app.toggleBarcodeScanFixedImage()
        app.togglePrettyStatusBar()
        super.tearDown()
    }
    
    func testSnapshot() {
        let app = ReadingListApplication()
        app.clickTab(.toRead)
        
        let isIpad = app.navigationBars.count == 2
        
        if isIpad {
            app.tables.cells.element(boundBy: 1).tap()
        }
        
        sleep(2)
        snapshot("0_ToReadList")
        
        app.clickTab(.finished)
        app.tables.staticTexts["Your First Swift App"].tap()
        snapshot("1_BookDetails")
        
        app.topNavBar.buttons.element(boundBy: 0).tap()
        app.clickAddButton(addMethod: .scanBarcode)
        sleep(1)
        snapshot("2_ScanBarcode")
        
        if isIpad {
            app.navigationBars["Scan Barcode"].buttons["Cancel"].tap()
            app.tables.staticTexts["The Noise of Time"].tap()
        }
        else {
            app.topNavBar.buttons.element(boundBy: 0).tap()
        }
        if #available(iOS 11.0, *) {
            app.tables.element(boundBy: 0).swipeDown()
            let yourLibrarySearchField = app.searchFields["Your Library"]
            yourLibrarySearchField.tap()
            yourLibrarySearchField.typeText("Orwell")
        }
        else {
            app.tables.searchFields.element(boundBy: 0).tap()
            app.typeText("Orwell")
        }
        app.buttons["Done"].tap()
        
        if isIpad {
            app.tables.staticTexts["Nineteen Eighty-Four"].tap()
        }
        sleep(1)
        snapshot("3_SearchFinished")
        
    }
}

