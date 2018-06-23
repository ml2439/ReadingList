import Foundation
import UIKit
import CloudKit
import SVProgressHUD

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
        if iCloudSyncOn {
            SVProgressHUD.show()
            appDelegate.syncCoordinator.remote.initialise { error in
                SVProgressHUD.dismiss()
                if let error = error {
                    self.handleRemoteInitialiseError(error: error)
                    sender.setOn(false, animated: true)
                } else {
                    UserSettings.iCloudSyncEnabled.value = iCloudSyncOn
                    appDelegate.syncCoordinator.start()
                }
            }
        } else {
            appDelegate.syncCoordinator.stop()
        }
    }

    private func handleRemoteInitialiseError(error: Error) {
        guard let ckError = error as? CKError else { fatalError("Unexpected error type") }
        
        switch ckError.code {
        case .notAuthenticated:
            let alert = UIAlertController(title: "Not Signed In", message: "iCloud sync could not be enabled because you are not signed in to iCloud.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
        default:
            let alert = UIAlertController(title: "Could not enable iCloud sync", message: "An error occurred enabling iCloud sync.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
        }
    }
}
