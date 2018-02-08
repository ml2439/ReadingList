import Foundation
import UIKit

class Fonts {
    private static let gillSansFont = UIFont(name: "GillSans", size: 12)!
    private static let gillSansSemiBoldFont = UIFont(name: "GillSans-Semibold", size: 12)!
    
    static func gillSans(ofSize: CGFloat) -> UIFont {
        return gillSansFont.withSize(ofSize)
    }
    
    static func gillSans(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        return gillSansFont.scaled(forTextStyle: textStyle)
    }
    
    static func gillSansSemiBold(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        return gillSansSemiBoldFont.scaled(forTextStyle: textStyle)
    }
}

class MarkdownWriter {
    let font: UIFont
    let boldFont: UIFont
    
    init(font: UIFont, boldFont: UIFont?) {
        self.font = font
        if let boldFont = boldFont {
            self.boldFont = boldFont
        }
        else {
            self.boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor, size: font.pointSize)
        }
    }
    
    func write(_ markdown: String) -> NSAttributedString {
        let boldedResult = NSMutableAttributedString()
        for (index, component) in markdown.components(separatedBy: "**").enumerated() {
            boldedResult.append(NSAttributedString(component, withFont: index % 2 == 0 ? font : boldFont))
        }
        return boldedResult
    }
}
