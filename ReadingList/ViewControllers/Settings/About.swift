import Foundation
import UIKit
import MessageUI

class About: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //initialise(withTheme: UserSettings.theme)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: UIApplication.shared.open(URL(string: "https://www.readinglistapp.xyz")!, options: [:])
        case 1: share(indexPath)
        case 2: contact()
        case 3: UIApplication.shared.open(URL(string: "https://github.com/AndrewBennet/readinglist")!, options: [:])
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
        tableView.rowHeight = UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: UIApplication.shared.open(URL(string: "https://icons8.com")!, options: [:])
        case 1: UIApplication.shared.open(URL(string: "https://github.com/xmartlabs/Eureka")!, options: [:])
        case 2: UIApplication.shared.open(URL(string: "https://github.com/dzenbot/DZNEmptyDataSet")!, options: [:])
        case 3: UIApplication.shared.open(URL(string: "https://github.com/SwiftyJSON/SwiftyJSON")!, options: [:])
        case 4: UIApplication.shared.open(URL(string: "https://github.com/SVProgressHUD/SVProgressHUD")!, options: [:])
        case 5: UIApplication.shared.open(URL(string: "https://github.com/davedelong/CHCSVParser")!, options: [:])
        case 6: UIApplication.shared.open(URL(string: "https://github.com/bizz84/SwiftyStoreKit")!, options: [:])
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

