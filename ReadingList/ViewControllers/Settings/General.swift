import Foundation
import UIKit

class General: UITableViewController {
    
    @IBOutlet weak var useLargeTitlesSwitch: UISwitch!
    @IBOutlet weak var sendAnalyticsSwitch: UISwitch!
    @IBOutlet weak var sendCrashReportsSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            useLargeTitlesSwitch.isOn = UserSettings.useLargeTitles.value
        }
        else {
            useLargeTitlesSwitch.isOn = false
            useLargeTitlesSwitch.isEnabled = false
        }
        
        sendAnalyticsSwitch.isOn = UserSettings.sendAnalytics.value
        sendCrashReportsSwitch.isOn = UserSettings.sendCrashReports.value
    }
    
    @IBAction func useLargeTitlesChanged(_ sender: UISwitch) {
        UserSettings.useLargeTitles.value = sender.isOn
    }
    
    @IBAction func crashReportsSwitchChanged(_ sender: UISwitch) {
        UserSettings.sendCrashReports.value = sender.isOn
        if sender.isOn {
            UserEngagement.logEvent(.enableCrashReports)
        }
        else {
            // If this is being turned off, let's try to persuade them to turn it back on
            UserEngagement.logEvent(.disableCrashReports)
            persuadeToKeepOn(title: "Turn off crash reports?", message: "Anonymous crash reports alert me if this app crashes, to help me fix bugs. The information never include any information about your books. Are you sure you want to turn this off?") { result in
                if result {
                    UserSettings.sendCrashReports.value = true
                    sender.isOn = true
                }
                else {
                    UserEngagement.logEvent(.disableCrashReports)
                }
            }
        }
    }
    
    @IBAction func analyticsSwitchChanged(_ sender: UISwitch) {
        UserSettings.sendAnalytics.value = sender.isOn
        if sender.isOn {
            UserEngagement.logEvent(.enableAnalytics)
        }
        else {
            // If this is being turned off, let's try to persuade them to turn it back on
            persuadeToKeepOn(title: "Turn off analytics?", message: "Anonymous usage statistics help prioritise development. These never include any information about your books. Are you sure you want to turn this off?") { result in
                if result {
                    UserSettings.sendAnalytics.value = true
                    sender.isOn = true
                }
                else {
                    UserEngagement.logEvent(.disableAnalytics)
                }
            }
        }
    }
    
    func persuadeToKeepOn(title: String, message: String, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Turn Off", style: .destructive) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: "Leave On", style: .default) { _ in
            completion(true)
        })
        present(alert, animated: true)
    }
}
