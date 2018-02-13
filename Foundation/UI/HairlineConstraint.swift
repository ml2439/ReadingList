import Foundation
import UIKit

class HairlineConstraint: NSLayoutConstraint {
    override func awakeFromNib() {
        super.awakeFromNib()
        constant = 1.0 / UIScreen.main.scale
    }
}
