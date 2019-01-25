import Foundation
import XCTest

class ReadingListApp: XCUIApplication {

    enum Tab: Int {
        case toRead = 0
        case finished = 1
        case organise = 2
        case settings = 3
    }

    enum AddMethod: Int {
        case scanBarcode = 0
        case searchOnline = 1
        case enterManually = 2
    }

    func clickTab(_ tab: Tab) {
        getTab(tab).tap()
    }

    func getTab(_ tab: Tab) -> XCUIElement {
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

    func clickAddButton(addMethod: AddMethod) {
        navigationBars.element(boundBy: 0).buttons["Add"].tap()
        sheets.buttons.element(boundBy: addMethod.rawValue).tap()
    }

    var topNavBar: XCUIElement {
        return navigationBars.element(boundBy: navigationBars.count - 1)
    }
}
