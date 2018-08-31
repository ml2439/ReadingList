import UIKit
import MessageUI
import ReadingList_Foundation

class Settings: UITableViewController {

    static let appStoreAddress = "itunes.apple.com/gb/app/reading-list-book-tracker/id1217139955"
    static let feedbackEmailAddress = "feedback@readinglist.app"
    static let joinBetaEmailSubject = "Join Reading List Beta"
    private let dataIndexPath = IndexPath(row: 2, section: 1)

    @IBOutlet private var headerLabels: [UILabel]!
    @IBOutlet private weak var versionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = "v\(BuildInfo.appVersion)"

        if #available(iOS 11.0, *) {
            monitorLargeTitleSetting()
        }
        monitorThemeSetting()

        #if DEBUG
        tableView.tableHeaderView!.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(onLongPressHeader(_:))))
        #endif

        DispatchQueue.main.async {
            // isSplit does not work correctly before the view is loaded; run this later
            if self.splitViewController!.isSplit {
                self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }

    #if DEBUG
    @objc func onLongPressHeader(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        present(Debug().inThemedNavController(), animated: true, completion: nil)
    }
    #endif

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let selectedIndex = tableView.indexPathForSelectedRow, !splitViewController!.isSplit {
            tableView.deselectRow(at: selectedIndex, animated: true)
        }
    }

    override func initialise(withTheme theme: Theme) {
        super.initialise(withTheme: theme)
        headerLabels.forEach { $0.textColor = theme.titleTextColor }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.defaultInitialise(withTheme: UserSettings.theme.value)
        if !appDelegate.tabBarController.selectedSplitViewController!.isSplit { return cell }

        // In split mode, change the cells a little to look more like the standard iOS settings app
        cell.selectedBackgroundView = UIView(backgroundColor: UIColor(fromHex: 5350396))
        cell.textLabel!.highlightedTextColor = UIColor.white
        cell.accessoryType = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 1):
            UIApplication.shared.open(URL(string: "itms-apps://\(Settings.appStoreAddress)?action=write-review")!, options: [:])
        case (1, 3):
            let canSendMail = MFMailComposeViewController.canSendMail()
            var message = """
                iCloud Sync is currently being developed. When available, this will synchronise books between different devices. \
                Until this is available, you can move your book data between devices manually by exporting and importing.

                If you want to help the development of iCloud Sync, you can join the beta program.
                """
            if !canSendMail {
                message += " To become a beta tester, please email \(Settings.feedbackEmailAddress) with the subject \"\(Settings.joinBetaEmailSubject)\"."
            }
            let alert = UIAlertController(title: "iCloud Sync coming soon", message: message, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Manual Export", style: .default) { _ in
                self.performSegue(withIdentifier: "settingsData", sender: self)
                if self.splitViewController!.isSplit {
                    self.tableView.selectRow(at: self.dataIndexPath, animated: false, scrollPosition: .none)
                }
            })
            if canSendMail {
                alert.addAction(UIAlertAction(title: "Join Beta", style: .default) { _ in
                    guard BuildInfo.appConfiguration != .testFlight else {
                        let controller = UIAlertController(title: "Already a Beta Tester", message: "You're already running a beta version of the app.", preferredStyle: .alert)
                        controller.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(controller, animated: true)
                        return
                    }

                    let betaWindow = About.betaMailComposeWindow()
                    betaWindow.mailComposeDelegate = self
                    self.present(betaWindow, animated: true)
                })
            }
            alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
            alert.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
            present(alert, animated: true)
        default:
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let url = sender as? URL, let nav = segue.destination as? UINavigationController, let data = nav.viewControllers.first as? DataVC {
            // In order to trigger an import from an external source, the presenting segue's sender is the URL of the file.
            // Set this on the Data vc, which will load the file the first time the VC appears after the import URL is set.
            data.importUrl = url
        }
    }
}

extension Settings: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}
