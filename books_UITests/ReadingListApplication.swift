//
//  ReadingListApplication.swift
//  books
//
//  Created by Andrew Bennet on 20/05/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

import Foundation
import XCTest

class ReadingListApplication : XCUIApplication {
    enum tab : Int {
        case toRead = 0
        case finished = 1
        case organise = 2
        case settings = 3
    }
    
    enum addMethod : Int {
        case scanBarcode = 0
        case searchOnline = 1
        case enterManually = 2
    }
    
    func clickTab(_ tab: tab) {
        getTab(tab).tap()
    }
    
    func getTab(_ tab: tab) -> XCUIElement {
        return tabBars.buttons.element(boundBy: tab.rawValue)
    }
    
    func waitUntilHittable(_ element: XCUIElement, failureMessage: String) {
        let startTime = NSDate.timeIntervalSinceReferenceDate
        
        while !element.isHittable {
            if NSDate.timeIntervalSinceReferenceDate - startTime > 30 {
                XCTAssert(false, failureMessage)
            }
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.1, false)
        }
    }
    
    func setBarcodeSimulation(_ mode: BarcodeScanSimulation) {
        clickTab(.settings)
        tables.cells.staticTexts["Debug"].tap()
        
        tables.cells.staticTexts[mode.titleText].tap()
        if navigationBars.count == 1 {
            topNavBar.buttons["Settings"].tap()
        }
    }
    
    func clickAddButton(addMethod: addMethod) {
        navigationBars.element(boundBy: 0).buttons["Add"].tap()
        sheets.buttons.element(boundBy: addMethod.rawValue).tap()
    }
    
    var topNavBar: XCUIElement {
        get {
            return navigationBars.element(boundBy: navigationBars.count - 1)
        }
    }
}
