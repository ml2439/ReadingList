import Foundation
import UIKit

@IBDesignable
public class HorizontalGradientView: UIView {

    public var colorPosition: NSNumber = 0.4 {
        didSet {
            setupGradient()
        }
    }

    public var color: UIColor = .white {
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

    public override func awakeFromNib() {
        super.awakeFromNib()
        setupGradient()
        layer.insertSublayer(gradient, at: 0)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
