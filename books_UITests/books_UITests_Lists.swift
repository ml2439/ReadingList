//
//  books_UITests_NoData.swift
//  books_UITests
//
//  Created by Andrew Bennet on 24/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation
import XCTest

class books_UITests_Lists: XCTestCase {
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        let app = ReadingListApplication()
        app.launchArguments.append("--UITests_PopulateData")
        app.launchArguments.append("--UITests_DeleteLists")
        app.launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAddFirstList() {
        
        
        let app = ReadingListApplication()
        app.tables.cells.element(boundBy: 0).tap()
/*
        let addNewListAlert = app.alerts["Add New List"]
        addNewListAlert.collectionViews.textFields["Enter list name"].typeText("t List")
        addNewListAlert.buttons["OK"].tap()
        app.tabBars.buttons["Organise"].tap()
 */
        
        
    }
}
