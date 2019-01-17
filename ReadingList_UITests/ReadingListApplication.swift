import Foundation
import XCTest

class ReadingListApplication: XCUIApplication {

    enum Tab: Int {
        case toRead = 0
        case finished = 1
        case organise = 2
        case settings = 3
    }

    enum BarcodeScanSimulation: Int {
        case none = 0
        case normal = 1
        case noCameraPermissions = 2
        case validIsbn = 3
        case unfoundIsbn = 4
        case existingIsbn = 5

        var titleText: String {
            switch self {
            case .none:
                return "None"
            case .normal:
                return "Normal"
            case .noCameraPermissions:
                return "No Camera Permissions"
            case .validIsbn:
                return "Valid ISBN"
            case .unfoundIsbn:
                return "Not-found ISBN"
            case .existingIsbn:
                return "Existing ISBN"
            }
        }
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

    func setBarcodeSimulation(_ mode: BarcodeScanSimulation) {
        clickTab(.settings)
        tables.otherElements.containing(.image, identifier: "AppIconOnWhiteRounded").element.press(forDuration: 1.0)

        tables.cells.staticTexts[mode.titleText].tap()
        navigationBars["Debug"].buttons["Dismiss"].tap()
    }

    func clickAddButton(addMethod: AddMethod) {
        navigationBars.element(boundBy: 0).buttons["Add"].tap()
        sheets.buttons.element(boundBy: addMethod.rawValue).tap()
    }

    var topNavBar: XCUIElement {
        return navigationBars.element(boundBy: navigationBars.count - 1)
    }
}
