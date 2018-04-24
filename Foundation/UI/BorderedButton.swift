import Foundation
import UIKit

@IBDesignable
class BorderedButton: UIButton {

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 12
        layer.borderWidth = 0
        setTitleColor(UIColor.white, for: state)
        setColor(tintColor)
    }

    func setColor(_ colour: UIColor) {
        backgroundColor = colour
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        awakeFromNib()
    }
}
