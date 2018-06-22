import Foundation
import UIKit

class CloudSync: UITableViewController {

    @IBOutlet private weak var enabledSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        monitorThemeSetting()
        enabledSwitch.isOn = UserSettings.iCloudSyncEnabled.value
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let theme = UserSettings.theme.value
        cell.defaultInitialise(withTheme: theme)
        cell.contentView.subviews.forEach {
            guard let label = $0 as? UILabel else { return }
            label.textColor = theme.titleTextColor
        }
        return cell
    }

    @IBAction private func iCloudSyncSwitchChanged(_ sender: UISwitch) {
        let iCloudSyncOn = sender.isOn
        UserSettings.iCloudSyncEnabled.value = iCloudSyncOn
        if iCloudSyncOn {
            appDelegate.syncCoordinator.start()
        } else {
            appDelegate.syncCoordinator.stop()
        }
    }
}
