import Foundation
import UIKit
import ReadingList_Foundation

class ExpandableLabel: UIView {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var gradientView: HorizontalGradientView!
    @IBOutlet weak var seeMoreLabel: UILabel!
    
    var shouldTruncateLongDescriptions = true
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(seeMore)))
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        if shouldTruncateLongDescriptions {
            gradientView.isHidden = true
            seeMoreLabel.isHidden = true
        }
        else if gradientView.isHidden == label.isTruncated {
            gradientView.isHidden = false
            seeMoreLabel.isHidden = false
        }
    }
    
    @objc func seeMore() {
        guard shouldTruncateLongDescriptions else { return }
        
        // We cannot just set isHidden to true here, because we cannot be sure whether the relayout will be called before or after
        // the description label starts reporting isTruncated = false.
        // Instead, store the knowledge that the button should be hidden here; when layout is called, if the button is disabled it will be hidden.
        shouldTruncateLongDescriptions = false
        label.numberOfLines = 0
        
        // Relaying out the parent is sometimes required
        superview?.layoutIfNeeded()
    }
}
