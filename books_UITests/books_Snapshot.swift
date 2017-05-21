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
        app.launch()
        app.addTestData()
        
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
        
        app.clickAddButton(addMethod: .scanBarcode)
        sleep(1)
        snapshot("1_ScanBarcode")
        app.topNavBar.buttons.element(boundBy: 0).tap()
        
        app.clickTab(.finished)
        app.tables.staticTexts["Your First Swift App"].tap()
        snapshot("2_BookDetails")
        if isIpad {
            app.tables.staticTexts["Nineteen Eighty-Four"].tap()
        }
        else {
            app.topNavBar.buttons.element(boundBy: 0).tap()
        }
        app.tables.searchFields.element(boundBy: 0).tap()
        app.typeText("Orwell")
        app.buttons["Done"].tap()

        sleep(1)
        snapshot("3_SearchFinished")
        
    }
}

