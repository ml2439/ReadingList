import Foundation
import UIKit

class SettingsHeader: UIView {
    @IBOutlet private weak var versionNumber: UILabel!
    @IBOutlet private weak var author: UILabel!
    @IBOutlet private weak var appName: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        versionNumber.text = "\(BuildInfo.appConfiguration.userFacingDescription)"
    }

    func initialise(withTheme theme: Theme) {
        versionNumber.textColor = theme.titleTextColor
        author.textColor = theme.titleTextColor
        appName.textColor = theme.titleTextColor
    }
}
