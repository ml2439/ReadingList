import Foundation
import UIKit

class SettingsHeader: UIView {
    @IBOutlet weak var versionNumber: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        versionNumber.text = "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)"
    }
}
