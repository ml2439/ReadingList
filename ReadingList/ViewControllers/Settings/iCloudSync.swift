import Foundation
import UIKit
import CloudKit
import SVProgressHUD
import Reachability

class CloudSync: UITableViewController {

    @IBOutlet private weak var enabledSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        monitorThemeSetting()
        enabledSwitch.isOn = UserSettings.iCloudSyncEnabled.value
        if !UserSettings.iCloudSyncEnabled.value && appDelegate.reachability.connection == .none {
            enabledSwitch.isEnabled = false
        }
        NotificationCenter.default.addObserver(self, selector: #selector(networkConnectivityDidChange), name: .reachabilityChanged, object: nil)
    }

    @objc private func networkConnectivityDidChange() {
        guard !UserSettings.iCloudSyncEnabled.value else { return }
        enabledSwitch.isEnabled = appDelegate.reachability.connection != .none
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
        if sender.isOn {
            turnOnSync()
        } else {
            turnOffSync()
        }
    }

    private func turnOnSync() {
        SVProgressHUD.show()
        appDelegate.syncCoordinator.remote.initialise { error in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                if let error = error {
                    self.handleRemoteInitialiseError(error: error)
                    self.enabledSwitch.setOn(false, animated: true)
                } else {
                    UserSettings.iCloudSyncEnabled.value = true
                    appDelegate.syncCoordinator.start()
                }
            }
        }
    }

    private func turnOffSync() {
        let alert = UIAlertController(title: "Disable Sync?", message: """
            If you disable iCloud sync, changes you make will no longer be \
            synchronised across your devices, or backed up in your iCloud account.

            Are you sure you want to disable iCloud sync?
            """, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { _ in
            // TODO: Consider whether change tokens should be discarded, remote identifiers should be deleted, etc
            appDelegate.syncCoordinator.stop()
        })
        alert.addAction(UIAlertAction(title: "No", style: .default) { [unowned self] _ in
            self.enabledSwitch.isOn = true
        })
        present(alert, animated: true)
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
