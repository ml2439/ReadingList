import UIKit
import Eureka

class DynamicUILabel: UILabel {
    @IBInspectable var dynamicFontSize: String = "Title1" {
        didSet {
            font = font.scaled(forTextStyle: UIFontTextStyle("UICTFontTextStyle\(dynamicFontSize)"))
        }
    }
}

@IBDesignable class RoundedImageView: UIImageView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
}

@IBDesignable class RoundedView: UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
}
