import Foundation
import UIKit
import Eureka

class General: FormViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            form +++ Section(header: "Appearance", footer: "")
                <<< SwitchRow() {
                    $0.title = "Use Large Titles"
                    $0.value = UserSettings.useLargeTitles.value
                    $0.onChange{ row in
                        UserSettings.useLargeTitles.value = row.value!
                        NotificationCenter.default.post(name: NSNotification.Name.LargeTitleSettingChanged, object: nil)
                    }
                }
        }
        
        func themeRow(_ theme: Theme, name: String) -> ListCheckRow<Theme> {
            return ListCheckRow<Theme>() {
                $0.title = name
                $0.selectableValue = theme
                $0.value = UserSettings.theme == theme ? theme : nil
            }
        }
        
        form +++ SelectableSection<ListCheckRow<Theme>>(header: "Theme", footer: "", selectionType: .singleSelection(enableDeselection: false)) {
                    $0.onSelectSelectableRow = { cell, row in
                        UserSettings.theme = row.value!
                        NotificationCenter.default.post(name: Notification.Name.ThemeSettingChanged, object: nil)
                    }
                }
                <<< themeRow(.normal, name: "Default")
                <<< themeRow(.dark, name: "Dark")
                <<< themeRow(.black, name: "Black")
            
            +++ Section(header: "Analytics", footer: "Reading List ...")
                <<< SwitchRow() {
                    $0.title = "Crash Reports"
                }
                <<< SwitchRow() {
                    $0.title = "Usage Reports"
                }
        
        monitorThemeSetting()
    }
}


class GeneralOld: UITableViewController {
    
    @IBOutlet weak var useLargeTitlesSwitch: UISwitch!
    @IBOutlet weak var sendAnalyticsSwitch: UISwitch!
    @IBOutlet weak var sendCrashReportsSwitch: UISwitch!
    @IBOutlet weak var darkModeSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            useLargeTitlesSwitch.isOn = UserSettings.useLargeTitles.value
        }
        else {
            useLargeTitlesSwitch.isOn = false
            useLargeTitlesSwitch.isEnabled = false
        }
        
        darkModeSwitch.isOn = UserSettings.theme != .normal
        sendAnalyticsSwitch.isOn = UserSettings.sendAnalytics.value
        sendCrashReportsSwitch.isOn = UserSettings.sendCrashReports.value
        
        monitorThemeSetting()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.contentView.subviews.flatMap{$0 as? UILabel}.forEach{
            $0.textColor = UserSettings.theme.titleTextColor
        }
        cell.backgroundColor = UserSettings.theme.cellBackgroundColor
        return cell
    }
    
    @IBAction func useLargeTitlesChanged(_ sender: UISwitch) {
        UserSettings.useLargeTitles.value = sender.isOn
        NotificationCenter.default.post(name: NSNotification.Name.LargeTitleSettingChanged, object: nil)
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
    
    @IBAction func darkModeSwitchToggled(_ sender: UISwitch) {
        UserSettings.theme = sender.isOn ? .dark : .normal
        NotificationCenter.default.post(name: Notification.Name.ThemeSettingChanged, object: nil)
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

extension Notification.Name {
    static let LargeTitleSettingChanged = Notification.Name("large-title-setting-changed")
    static let ThemeSettingChanged = Notification.Name("theme-setting-changed")
}

extension UIViewController {
    @available(iOS 11.0, *)
    func monitorLargeTitleSetting() {
        updateLargeTitleFromSetting()
        NotificationCenter.default.addObserver(self, selector: #selector(updateLargeTitleFromSetting), name: NSNotification.Name.LargeTitleSettingChanged, object: nil)
    }
    
    @available(iOS 11.0, *)
    @objc private func updateLargeTitleFromSetting() {
        guard let navController = navigationController else { return }
        navController.navigationBar.prefersLargeTitles = UserSettings.useLargeTitles.value
    }
}
