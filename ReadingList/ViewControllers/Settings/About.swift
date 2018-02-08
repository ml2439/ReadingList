import Foundation
import UIKit

class About: UITableViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        switch indexPath.row {
            
        case 0: UIApplication.shared.open(URL(string: "https://www.readinglistapp.xyz")!, options: [:])
        case 2: UIApplication.shared.open(URL(string: "https://github.com/AndrewBennet/readinglist")!, options: [:])
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

