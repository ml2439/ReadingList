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
                    DebugSettings.loadTestData {
                        SVProgressHUD.dismiss()
                    }
                }
            }

        +++ SelectableSection<ListCheckRow<BarcodeScanSimulation>>("Barcode scan behaviour", selectionType: .singleSelection(enableDeselection: false)) {
            let currentValue = DebugSettings.barcodeScanSimulation
            for option: BarcodeScanSimulation in [.none, .normal, .noCameraPermissions, .validIsbn, .unfoundIsbn, .existingIsbn] {
                $0 <<< ListCheckRow<BarcodeScanSimulation> {
                    $0.title = option.titleText
                    $0.selectableValue = option
                    $0.value = (option == currentValue ? option : nil)
                    $0.onChange {
                        DebugSettings.barcodeScanSimulation = $0.value ?? .none
                    }
                }
            }
        }

        +++ SelectableSection<ListCheckRow<QuickActionSimulation>>("Quick Action Simulation", selectionType: .singleSelection(enableDeselection: false)) {
            let currentQuickActionValue = DebugSettings.quickActionSimulation
            for quickActionOption: QuickActionSimulation in [.none, .barcodeScan, .searchOnline] {
                $0 <<< ListCheckRow<QuickActionSimulation> {
                    $0.title = quickActionOption.titleText
                    $0.selectableValue = quickActionOption
                    $0.value = (quickActionOption == currentQuickActionValue ? quickActionOption : nil)
                    $0.onChange {
                        DebugSettings.quickActionSimulation = $0.value ?? .none
                    }
                }
            }
        }

        +++ Section("Debug Controls")
            <<< SwitchRow {
                $0.title = "Show sort number"
                $0.value = DebugSettings.showSortNumber
                $0.onChange {
                    DebugSettings.showSortNumber = $0.value ?? false
                }
            }

        +++ Section("iCloud Sync")
            <<< ButtonRow {
                $0.title = "Simulate remote change notification"
                $0.disabled = Condition(booleanLiteral: !UserSettings.iCloudSyncEnabled.value || appDelegate.syncCoordinator?.remote.isInitialised != true)
                $0.onCellSelection { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if UserSettings.iCloudSyncEnabled.value, let syncCoordinator = appDelegate.syncCoordinator, syncCoordinator.remote.isInitialised {
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
