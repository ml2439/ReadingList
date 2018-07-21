import Foundation
import UIKit

extension UIFont {
    static let gillSans = UIFont(name: "GillSans", size: 12)!
    static let gillSansSemiBold = UIFont(name: "GillSans-Semibold", size: 12)!

    static func gillSans(ofSize: CGFloat) -> UIFont {
        return gillSans.withSize(ofSize)
    }

    static func gillSans(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        return gillSans.scaled(forTextStyle: textStyle)
    }

    static func gillSansSemiBold(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        return gillSansSemiBold.scaled(forTextStyle: textStyle)
    }
}
