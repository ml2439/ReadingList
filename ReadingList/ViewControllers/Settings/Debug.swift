#if DEBUG

import Foundation
import Eureka
import SVProgressHUD
import Crashlytics

class Debug: FormViewController {

    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Debug"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Dismiss", style: .plain, target: self, action: #selector(dismissSelf))

        form +++ Section(header: "Test data", footer: "Import a set of data for both testing and screenshots")
            <<< ButtonRow {
                $0.title = "Import Test Data"
                $0.onCellSelection { _, _ in
                    SVProgressHUD.show(withStatus: "Loading Data...")
                    DebugSettings.loadData {
                        SVProgressHUD.dismiss()
                    }
                }
            }

        +++ Section("Debug Controls")
            <<< SwitchRow {
                $0.title = "Show sort number"
                $0.value = UserDefaults.standard[.showSortNumber]
                $0.onChange {
                    UserDefaults.standard[.showSortNumber] = $0.value ?? false
                }
            }

        +++ Section("iCloud Sync")
            <<< ButtonRow {
                $0.title = "Simulate remote change notification"
                $0.disabled = Condition(booleanLiteral: !UserDefaults.standard[.iCloudSyncEnabled] || appDelegate.syncCoordinator?.remote.isInitialised != true)
                $0.onCellSelection { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if UserDefaults.standard[.iCloudSyncEnabled], let syncCoordinator = appDelegate.syncCoordinator, syncCoordinator.remote.isInitialised {
                            syncCoordinator.remoteNotificationReceived { _ in }
                        }
                    }
                }
            }

        +++ Section("Error reporting")
            <<< ButtonRow {
                $0.title = "Crash"
                $0.cellUpdate { cell, _ in
                    cell.textLabel?.textColor = .red
                }
                $0.onCellSelection { _, _ in
                    Crashlytics.sharedInstance().crash()
                }
            }

        monitorThemeSetting()
    }
}

#endif
