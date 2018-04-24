import Foundation
import UIKit
import DZNEmptyDataSet

func duplicateBookAlertController(goToExistingBook: @escaping () -> Void, cancel: @escaping () -> Void) -> UIAlertController {

    let alert = UIAlertController(title: "Book Already Added", message: "A book with the same ISBN or Google Books ID has already been added to your reading list.", preferredStyle: UIAlertControllerStyle.alert)

    // "Go To Existing Book" option - dismiss the provided ViewController (if there is one), and then simulate the book selection
    alert.addAction(UIAlertAction(title: "Go To Existing Book", style: UIAlertActionStyle.default) { _ in
        goToExistingBook()
    })

    // "Cancel" should just envoke the callback
    alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { _ in
        cancel()
    })

    return alert
}

class StandardEmptyDataset {

    static func title(withText text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [NSAttributedStringKey.font: UIFont.gillSans(ofSize: 32),
                                                             NSAttributedStringKey.foregroundColor: UserSettings.theme.value.titleTextColor])
    }

    static func description(withMarkdownText markdownText: String) -> NSAttributedString {
        let bodyFont = UIFont.gillSans(forTextStyle: .title2)
        let boldFont = UIFont.gillSansSemiBold(forTextStyle: .title2)

        let markedUpString = NSAttributedString.createFromMarkdown(markdownText, font: bodyFont, boldFont: boldFont)
        markedUpString.addAttribute(NSAttributedStringKey.foregroundColor, value: UserSettings.theme.value.subtitleTextColor, range: NSRange(location: 0, length: markedUpString.string.count))
        return markedUpString
    }
}
