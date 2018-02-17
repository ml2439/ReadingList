import UIKit
import CoreSpotlight
import Eureka

class TabBarController: UITabBarController {
    
    enum TabOption : Int {
        case toRead = 0
        case finished = 1
        case organise = 2
        case settings = 3
    }
    
    func selectTab(_ tab: TabOption) {
        selectedIndex = tab.rawValue
    }
    
    func selectTab(forState state: BookReadState) -> BookTable {
        selectTab(state == .finished ? .finished : .toRead)
        return selectedBookTable!
    }
    
    var selectedTab: TabOption {
        get { return TabOption(rawValue: selectedIndex)! }
    }
    
    var selectedReadState: BookReadState {
        get { return selectedTab == .finished ? .finished : .toRead }
    }
    
    var selectedSplitViewController: SplitViewController? {
        get { return selectedViewController as? SplitViewController }
    }

    var selectedBookTable: BookTable? {
        get { return (selectedSplitViewController?.masterNavigationController.viewControllers.first as? BookTable) }
    }
    
    func simulateBookSelection(_ book: Book, allowTableObscuring: Bool) {
        selectTab(forState: book.readState).simulateBookSelection(book, allowTableObscuring: allowTableObscuring)
    }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let selectedSplitViewController = selectedSplitViewController, item.tag == selectedIndex {
            
            if selectedSplitViewController.masterNavigationController.viewControllers.count > 1 {
               selectedSplitViewController.masterNavigationController.popToRootViewController(animated: true)
            }
            else if let topVc = selectedSplitViewController.masterNavigationController.viewControllers.first,
                let topTable = (topVc as? UITableViewController)?.tableView ?? (topVc as? FormViewController)?.tableView,
                topTable.numberOfSections > 0, topTable.contentOffset.y > 0 {
                    topTable.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            }
        }
    }
}
