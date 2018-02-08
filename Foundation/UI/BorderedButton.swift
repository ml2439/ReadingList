import Foundation
import UIKit

@IBDesignable
class BorderedButton: UIButton {
    @IBInspectable var cornerRadius: CGFloat = 12
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = cornerRadius
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
