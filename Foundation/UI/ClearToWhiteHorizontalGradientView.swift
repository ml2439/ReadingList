import Foundation
import UIKit

@IBDesignable
class ClearToWhiteHorizontalGradientView: UIView {
    
    @IBInspectable var whitePosition: NSNumber = 0.4 {
        didSet {
            setupGradient()
        }
    }
    
    var gradient = CAGradientLayer()
    
    func setupGradient() {
        let white = UIColor.white.withAlphaComponent(1.0)
        let clear = UIColor.white.withAlphaComponent(0.0)
        gradient.colors = [clear.cgColor, white.cgColor]
        gradient.locations = [0.0, whitePosition]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.frame = bounds
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupGradient()
        layer.insertSublayer(gradient, at: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

