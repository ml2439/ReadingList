import Foundation
import UIKit

@IBDesignable
public class ExpandableLabel: UIView {

    private let label = UILabel(frame: .zero)
    private let seeMore = UILabel(frame: .zero)
    private let gradientView = UIView(frame: .zero)
    private let gradient = CAGradientLayer()

    public override init(frame: CGRect) {
        super.init(frame: .zero)
        self.setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    @IBInspectable public var text: String? {
        didSet { label.text = text }
    }

    @IBInspectable public var color: UIColor = .black {
        didSet { label.textColor = color }
    }

    public var gradientColor: UIColor = .white {
        didSet {
            seeMore.backgroundColor = gradientColor
            setupGradient()
        }
    }

    @IBInspectable public var numberOfLines: Int = 4 {
        didSet { label.numberOfLines = numberOfLines }
    }

    public var font: UIFont {
        get { return label.font }
        set {
            label.font = newValue
            seeMore.font = newValue
        }
    }

    private var shouldTruncateLongDescriptions = true

    private func setup() {
        super.awakeFromNib()

        font = UIFont.systemFont(ofSize: 12.0)
        seeMore.text = "see more"
        seeMore.textColor = tintColor

        label.translatesAutoresizingMaskIntoConstraints = false
        seeMore.translatesAutoresizingMaskIntoConstraints = false
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        addSubview(gradientView)
        addSubview(seeMore)

        func pin(_ view: UIView, to other: UIView, multiplier: CGFloat = 1.0, attributes: NSLayoutAttribute...) {
            for attribute in attributes {
                NSLayoutConstraint(item: view, attribute: attribute, relatedBy: .equal, toItem: other,
                                   attribute: attribute, multiplier: multiplier, constant: 0.0).isActive = true
            }
        }

        pin(label, to: self, attributes: .leading, .trailing, .top, .bottom)
        pin(seeMore, to: self, attributes: .trailing, .bottom)
        pin(gradientView, to: seeMore, attributes: .trailing, .bottom, .height)
        pin(gradientView, to: seeMore, multiplier: 2.0, attributes: .width)

        setupGradient()
        gradientView.layer.insertSublayer(gradient, at: 0)
        gradientView.isOpaque = true

        invalidateIntrinsicContentSize()
        layoutIfNeeded()

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(seeMoreTapped)))
    }
    
    func setupGradient() {
        let opaque = gradientColor.withAlphaComponent(1.0)
        let clear = gradientColor.withAlphaComponent(0.0)
        gradient.colors = [clear.cgColor, opaque.cgColor]
        gradient.locations = [0.0, 0.4]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 0)
    }

    override public func layoutIfNeeded() {
        super.layoutIfNeeded()
        gradient.frame = gradientView.bounds

        if !shouldTruncateLongDescriptions {
            gradientView.isHidden = true
            seeMore.isHidden = true
        } else if gradientView.isHidden == label.isTruncated {
            gradientView.isHidden = false
            seeMore.isHidden = false
        }
    }

    override public var intrinsicContentSize: CGSize {
        return label.intrinsicContentSize
    }

    @objc private func seeMoreTapped() {
        guard shouldTruncateLongDescriptions else { return }

        // We cannot just set isHidden to true here, because we cannot be sure whether the relayout will be called before or after
        // the description label starts reporting isTruncated = false.
        // Instead, store the knowledge that the button should be hidden here; when layout is called, if the button is disabled it will be hidden.
        shouldTruncateLongDescriptions = false
        label.numberOfLines = 0

        // Relaying out the parent is sometimes required
        layoutIfNeeded()
    }
}
