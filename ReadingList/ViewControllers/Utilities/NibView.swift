import Foundation
import UIKit

class NibView {
    static func withName(_ name: String) -> UIView {
        return UINib(nibName: name, bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! UIView
    }
    
    static var searchBooksEmptyDataset: SearchBooksEmptyDataset {
        get { return NibView.withName("SearchBooksEmptyDataset") as! SearchBooksEmptyDataset }
    }
}

// From https://medium.com/zenchef-tech-and-product/how-to-visualize-reusable-xibs-in-storyboards-using-ibdesignable-c0488c7f525d
//@IBDesignable
class XibView: UIView {
    
    var contentView: UIView?
    
    @IBInspectable var nibName: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        xibSetup()
    }
    
    func xibSetup() {
        guard let view = loadViewFromNib() else { return }
        view.frame = bounds
        view.autoresizingMask =
            [.flexibleWidth, .flexibleHeight]
        addSubview(view)
        contentView = view
    }
    
    func loadViewFromNib() -> UIView? {
        guard let nibName = nibName else { return nil }
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(
            withOwner: self,
            options: nil).first as? UIView
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        xibSetup()
        contentView?.prepareForInterfaceBuilder()
    }
}
