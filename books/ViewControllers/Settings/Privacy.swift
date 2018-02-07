import Foundation
import UIKit

class Privacy: UITableViewController {
    
    @IBOutlet weak var sendAnalyticsSwitch: UISwitch!
    @IBOutlet weak var sendCrashReportsSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        sendAnalyticsSwitch.isOn = UserSettings.sendAnalytics.value
        sendCrashReportsSwitch.isOn = UserSettings.sendCrashReports.value
    }
    
    @IBAction func crashReportsSwitchChanged(_ sender: UISwitch) {
        UserSettings.sendCrashReports.value = sender.isOn
        if sender.isOn {
            UserEngagement.logEvent(.enableCrashReports)
        }
        else {
            // If this is being turned off, let's try to persuade them to turn it back on
            UserEngagement.logEvent(.disableCrashReports)
            persuadeToKeepOn(title: "Turn off crash reports?", message: "Anonymous crash reports alert me if this app crashes, to help me fix bugs. The information never include any information about your books. Are you sure you want to turn this off?", uiSwitch: sender)
        }
    }

    @IBAction func analyticsSwitchChanged(_ sender: UISwitch) {
        UserSettings.sendAnalytics.value = sender.isOn
        if sender.isOn {
            UserEngagement.logEvent(.enableAnalytics)
        }
        else {
            // If this is being turned off, let's try to persuade them to turn it back on
            UserEngagement.logEvent(.disableAnalytics)
            persuadeToKeepOn(title: "Turn off analytics?", message: "Anonymous usage statistics help prioritise development. These never include any information about your books. Are you sure you want to turn this off?", uiSwitch: sender)
        }
    }

    func persuadeToKeepOn(title: String, message: String, uiSwitch: UISwitch) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Turn Off", style: .destructive))
        alert.addAction(UIAlertAction(title: "Leave On", style: .default) { _ in
            // Switch it back on
            uiSwitch.setOn(true, animated: true)
            UserSettings.sendAnalytics.value = true
        })
        present(alert, animated: true)
    }
}
