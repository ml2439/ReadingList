import Foundation
import UIKit

class SettingsHeader: UIView {
    @IBOutlet weak var versionNumber: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        versionNumber.text = "\(BuildInfo.appConfiguration.userFacingDescription)"
    }
}
