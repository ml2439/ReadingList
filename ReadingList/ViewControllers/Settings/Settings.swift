import UIKit
import SVProgressHUD
import Crashlytics
import MessageUI

class Settings: UITableViewController, MFMailComposeViewControllerDelegate {

    static let appStoreAddress = "itunes.apple.com/gb/app/reading-list-book-tracker/id1217139955"
    static let feedbackEmailAddress = "feedback@readinglistapp.xyz"
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if #available(iOS 11.0, *) {
            navigationController!.navigationBar.prefersLargeTitles = UserSettings.useLargeTitles.value
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch (indexPath.section, indexPath.row) {
        case (0, 1): contact()
        case (0, 2): UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "itms-apps://\(Settings.appStoreAddress)?action=write-review")!)
        default: return
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
    
    func contact() {
        let canSendEmail = MFMailComposeViewController.canSendMail()

        let alert = UIAlertController(title: "Send Feedback?", message: "If you have any questions, comments or suggestions, please email me\(canSendEmail ? "." : " at \(Settings.feedbackEmailAddress).") I'll do my best to respond.", preferredStyle: .alert)
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
          App Version: \(appDelegate.appVersion) (\(appDelegate.appBuildNumber))
          iOS Version: \(UIDevice.current.systemVersion)
          Device: \(UIDevice.current.modelName)
        """
        mailComposer.setMessageBody(messageBody, isHTML: false)
        present(mailComposer, animated: true)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}

