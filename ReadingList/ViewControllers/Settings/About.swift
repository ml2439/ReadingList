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
        cell.defaultInitialise(withTheme: UserSettings.theme.value)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: presentThemedSafariViewController(URL(string: "https://www.readinglist.app")!)
        case 1: share(indexPath)
        case 2: contact(indexPath)
        case 3: joinBeta(indexPath)
        case 4: presentThemedSafariViewController(URL(string: "https://github.com/AndrewBennet/readinglist")!)
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func share(_ indexPath: IndexPath) {
        let appStoreUrl = URL(string: "https://\(Settings.appStoreAddress)")!
        let activityViewController = UIActivityViewController(activityItems: [appStoreUrl], applicationActivities: nil)
        activityViewController.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
        present(activityViewController, animated: true)
    }

    private func contact(_ indexPath: IndexPath) {
        let canSendEmail = MFMailComposeViewController.canSendMail()

        let controller = UIAlertController(title: "Send Feedback?", message: """
            If you have any questions or suggestions, please email me\
            \(canSendEmail ? "." : " at \(Settings.feedbackEmailAddress).") \
            I'll do my best to respond.
            """, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
            if canSendEmail {
                self.presentContactMailComposeWindow()
            }
        })
        if canSendEmail {
            controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        }
        controller.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView, arrowDirections: [.up, .down])

        present(controller, animated: true)
    }

    private func joinBeta(_ indexPath: IndexPath) {
        guard BuildInfo.appConfiguration != .testFlight else {
            let controller = UIAlertController(title: "Already a Beta Tester", message: "You're already running a beta version of the app.", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(controller, animated: true)
            return
        }

        let canSendMail = MFMailComposeViewController.canSendMail()

        var betaTestPopupText = """
            If you would like to help the development of this app, you can become a Beta Tester. \
            This will give you early access to app updates in order to test new features.
            """
        if !canSendMail {
            betaTestPopupText += "\n\nTo become a beta tester, please email \(Settings.feedbackEmailAddress) with the subject \"Join Reading List Beta\"."
        }
        let controller = UIAlertController(title: "Become a Beta Tester?", message: betaTestPopupText, preferredStyle: .actionSheet)
        if canSendMail {
            controller.addAction(UIAlertAction(title: "Join", style: .default) { [unowned self] _ in
                self.presentBetaMailComposeWindow()
            })
            controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        } else {
            controller.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        controller.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView, arrowDirections: [.up, .down])
        present(controller, animated: true)
    }

    private func presentBetaMailComposeWindow() {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients(["Reading List Developer <\(Settings.feedbackEmailAddress)>"])
        mailComposer.setSubject("Join Reading List Beta")
        let messageBody = """
        To enroll in the Reading List beta, please send this from the email address associated with your Apple ID, or type that email address here:


        App Version: \(BuildInfo.appConfiguration.userFacingDescription)
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.modelName)
        """
        mailComposer.setMessageBody(messageBody, isHTML: false)
        present(mailComposer, animated: true)
    }

    private func presentContactMailComposeWindow() {
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
        let theme = UserSettings.theme.value
        cell.defaultInitialise(withTheme: theme)
        cell.contentView.subviews.forEach {
            guard let label = $0 as? UILabel else { return }
            label.textColor = theme.titleTextColor
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: presentThemedSafariViewController(URL(string: "https://icons8.com")!)
        case 1: presentThemedSafariViewController(URL(string: "https://github.com/xmartlabs/Eureka")!)
        case 2: presentThemedSafariViewController(URL(string: "https://github.com/dzenbot/DZNEmptyDataSet")!)
        case 3: presentThemedSafariViewController(URL(string: "https://github.com/SwiftyJSON/SwiftyJSON")!)
        case 4: presentThemedSafariViewController(URL(string: "https://github.com/SVProgressHUD/SVProgressHUD")!)
        case 5: presentThemedSafariViewController(URL(string: "https://github.com/davedelong/CHCSVParser")!)
        case 6: presentThemedSafariViewController(URL(string: "https://github.com/bizz84/SwiftyStoreKit")!)
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
