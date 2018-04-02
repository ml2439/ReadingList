import Foundation
import UIKit

@IBDesignable
class HorizontalGradientView: UIView {
    
    @IBInspectable var colorPosition: NSNumber = 0.4 {
        didSet {
            setupGradient()
        }
    }
    
    var color: UIColor = .white {
        didSet {
            setupGradient()
        }
    }
    
    var gradient = CAGradientLayer()
    
    func setupGradient() {
        let opaque = color.withAlphaComponent(1.0)
        let clear = color.withAlphaComponent(0.0)
        gradient.colors = [clear.cgColor, opaque.cgColor]
        gradient.locations = [0.0, colorPosition]
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

