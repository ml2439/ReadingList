import Foundation
import UIKit

public class HairlineConstraint: NSLayoutConstraint {
    public override func awakeFromNib() {
        super.awakeFromNib()
        constant = 1.0 / UIScreen.main.scale
    }
}
