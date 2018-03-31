import Foundation
import UIKit
import MessageUI

class About: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        monitorThemeSetting()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.defaultInitialise(withTheme: UserSettings.theme)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: presentSafariViewController(url: "https://www.readinglistapp.xyz")
        case 1: share(indexPath)
        case 2: contact()
        case 3: presentSafariViewController(url: "https://github.com/AndrewBennet/readinglist")
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func share(_ indexPath: IndexPath) {
        let activityViewController = UIActivityViewController(activityItems: [URL(string: "https://\(Settings.appStoreAddress)")!], applicationActivities: nil)
        activityViewController.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
        present(activityViewController, animated: true)
    }

    func contact() {
        let canSendEmail = MFMailComposeViewController.canSendMail()
        
        let alert = UIAlertController(title: "Send Feedback?", message: "If you have any questions or suggestions, please email me\(canSendEmail ? "." : " at \(Settings.feedbackEmailAddress).") I'll do my best to respond.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default){ [unowned self] _ in
            if canSendEmail {
                self.presentMailComposeWindow()
            }
        })
        if canSendEmail {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        }
        present(alert, animated: true)
    }
    
    func presentMailComposeWindow() {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients(["Reading List Developer <\(Settings.feedbackEmailAddress)>"])
        mailComposer.setSubject("Reading List Feedback")
        let messageBody = """
        Your Message Here:
        
        
        
        
        Extra Info:
        App Version: \(BuildInfo.appConfiguration.userFacingDescription)
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.modelName)
        """
        mailComposer.setMessageBody(messageBody, isHTML: false)
        present(mailComposer, animated: true)
    }
}

extension About: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}

class Attributions: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        monitorThemeSetting()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        guard indexPath.section == 0 else { return cell }
        
        let theme = UserSettings.theme
        cell.contentView.subviews.compactMap({$0 as? UILabel}).forEach{
            $0.textColor = theme.titleTextColor
        }
        cell.backgroundColor = theme.cellBackgroundColor
        cell.selectedBackgroundView = UIView(backgroundColor: .lightGray)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: presentSafariViewController(url: "https://icons8.com")
        case 1: presentSafariViewController(url: "https://github.com/xmartlabs/Eureka")
        case 2: presentSafariViewController(url: "https://github.com/dzenbot/DZNEmptyDataSet")
        case 3: presentSafariViewController(url: "https://github.com/SwiftyJSON/SwiftyJSON")
        case 4: presentSafariViewController(url: "https://github.com/SVProgressHUD/SVProgressHUD")
        case 5: presentSafariViewController(url: "https://github.com/davedelong/CHCSVParser")
        case 6: presentSafariViewController(url: "https://github.com/bizz84/SwiftyStoreKit")
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

