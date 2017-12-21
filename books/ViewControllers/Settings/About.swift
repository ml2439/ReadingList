//
//  About.swift
//  books
//
//  Created by Andrew Bennet on 04/11/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit

class About: UITableViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://www.readinglistapp.xyz")!)
        case 2: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/AndrewBennet/readinglist")!)
        case 3: share()
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func share() {
        let activityViewController = UIActivityViewController(activityItems: [URL(string: "https://\(Settings.appStoreAddress)")!], applicationActivities: nil)
        if let popPresenter = activityViewController.popoverPresentationController {
            let cell = self.tableView.cellForRow(at: IndexPath(row: 2, section: 0))!
            popPresenter.sourceRect = cell.frame
            popPresenter.sourceView = self.tableView
            popPresenter.permittedArrowDirections = .any
        }
        present(activityViewController, animated: true)
    }
}

class Attributions: UITableViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
        case 0: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://icons8.com")!)
        case 1: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/xmartlabs/Eureka")!)
        case 2: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/dzenbot/DZNEmptyDataSet")!)
        case 3: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/SwiftyJSON/SwiftyJSON")!)
        case 4: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/SVProgressHUD/SVProgressHUD")!)
        case 5: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/davedelong/CHCSVParser")!)
        case 6: UIApplication.shared.openUrlPlatformSpecific(url: URL(string: "https://github.com/bizz84/SwiftyStoreKit")!)
        default: return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

