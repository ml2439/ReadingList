import UIKit
import MessageUI

class Settings: UITableViewController {

    @IBOutlet private weak var header: XibView!
    static let appStoreAddress = "itunes.apple.com/gb/app/reading-list-book-tracker/id1217139955"
    static let feedbackEmailAddress = "feedback@readinglist.app"
    static let joinBetaEmailSubject = "Join Reading List Beta"
    private let dataIndexPath = IndexPath(row: 2, section: 1)

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            monitorLargeTitleSetting()
        }
        monitorThemeSetting()

        DispatchQueue.main.async {
            // isSplit does not work correctly before the view is loaded; run this later
            if self.splitViewController!.isSplit {
                self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let selectedIndex = tableView.indexPathForSelectedRow, !splitViewController!.isSplit {
            tableView.deselectRow(at: selectedIndex, animated: true)
        }
    }

    override func initialise(withTheme theme: Theme) {
        super.initialise(withTheme: theme)
        (header.contentView as! SettingsHeader).initialise(withTheme: theme)
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
        default:
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        #if DEBUG
            return super.tableView(tableView, numberOfRowsInSection: section)
        #else
            // Hide the Debug cell
            let realCount = super.tableView(tableView, numberOfRowsInSection: section)
            return section == 1 ? realCount - 1 : realCount
        #endif
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
