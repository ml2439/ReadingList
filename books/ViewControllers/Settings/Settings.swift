//
//  Settings.swift
//  books
//
//  Created by Andrew Bennet on 23/10/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import UIKit
import SVProgressHUD
import Crashlytics
import MessageUI

class Settings: UITableViewController, MFMailComposeViewControllerDelegate {

    static let appStoreAddress = "itunes.apple.com/gb/app/reading-list-book-tracker/id1217139955"
    
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
        let toEmail = "feedback@readinglistapp.xyz"
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertController(title: "Can't send email", message: "Couldn't find any email accounts. If you want to give feedback, email \(toEmail)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients(["Reading List Developer <\(toEmail)>"])
        mailComposer.setSubject("Reading List Feedback")
        let messageBody = """
        
        
        
        ----
        App Version: \(appDelegate.appVersion) (\(appDelegate.appBuildNumber))
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.modelIdentifier)
        """
        mailComposer.setMessageBody(messageBody, isHTML: false)
        present(mailComposer, animated: true)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}

