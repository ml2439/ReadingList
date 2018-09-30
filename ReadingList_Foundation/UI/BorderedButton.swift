import Foundation
import UIKit

@IBDesignable
open class BorderedButton: UIButton {

    open override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 12
        layer.borderWidth = 0
        setTitleColor(.white, for: state)
        setColor(tintColor)
    }

    public func setColor(_ colour: UIColor) {
        backgroundColor = colour
    }

    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        awakeFromNib()
    }
}
