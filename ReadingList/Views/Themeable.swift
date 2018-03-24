import UIKit
import Foundation
import Eureka

@objc enum Theme: Int {
    case normal = 1
    case dark = 2
    case black = 3
}

extension Theme {
    var keyboardAppearance: UIKeyboardAppearance {
        return self == .normal ? .default : .dark
    }
    
    var titleTextColor: UIColor {
        return self == .normal ? .black : .white
    }
    
    var subtitleTextColor: UIColor {
        return self == .normal ? .darkGray : .white
    }
    
    var cellBackgroundColor: UIColor {
        switch self {
        case .normal: return .white
        case .dark: return .darkGray
        case .black: return .black
        }
    }
    
    var viewBackgroundColor: UIColor {
        switch self {
        case .normal: return .white
        case .dark: return .darkGray
        case .black: return .black
        }
    }
}

extension UITableViewCell {
    func defaultInitialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
        detailTextLabel?.textColor = theme.titleTextColor
        selectedBackgroundView = UIView(backgroundColor: .lightGray)
    }
}

extension ThemeableViewController {
    func monitorThemeSetting() {
        initialise(withTheme: UserSettings.theme)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.ThemeSettingChanged, object: nil, queue: nil) {_ in
            UIView.transition(with: self.view, duration: 0.3, options: [UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptions.transitionCrossDissolve], animations: {
                self.initialise(withTheme: UserSettings.theme)
                self.themeSettingDidChange?()
            }, completion: nil)
        }
    }
}

@objc protocol ThemeableViewController where Self: UIViewController {
    func standardInitialisation(withTheme theme: Theme)
    @objc optional func specificInitialisation(forTheme theme: Theme)
    @objc optional func themeSettingDidChange()
}

extension ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        if #available(iOS 11.0, *) {
            navigationItem.searchController?.searchBar.initialise(withTheme: theme)
        }
        standardInitialisation(withTheme: theme)
        specificInitialisation?(forTheme: theme)
    }
}

extension UITabBarController: ThemeableViewController {
    func standardInitialisation(withTheme theme: Theme) {
        tabBar.initialise(withTheme: theme)
    }
}

extension UITableViewController: ThemeableViewController {
    func standardInitialisation(withTheme theme: Theme) {
        tableView.initialise(withTheme: theme)
    }
    
    func themeSettingDidChange() {
        // Saw some weird artifacts which went away when the selected rows were deselected
        if let selectedRows = tableView.indexPathsForSelectedRows {
            selectedRows.forEach{tableView.deselectRow(at: $0, animated: false)}
        }
        tableView.reloadData()
    }
}

extension FormViewController: ThemeableViewController {
    func standardInitialisation(withTheme theme: Theme) {
        tableView.initialise(withTheme: theme)
    }
    
    func themeSettingDidChange() {
        // Saw some weird artifacts which went away when the selected rows were deselected
        if let selectedRows = tableView.indexPathsForSelectedRows {
            selectedRows.forEach{tableView.deselectRow(at: $0, animated: false)}
        }
        tableView.reloadData()
    }
}


class ThemedNavigationController: UINavigationController, ThemeableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        monitorThemeSetting()
    }
    
    func standardInitialisation(withTheme theme: Theme) {
        navigationBar.initialise(withTheme: theme)
    }
}

extension UINavigationBar {
    
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.viewBackgroundColor
        barTintColor = theme.viewBackgroundColor
        titleTextAttributes = [NSAttributedStringKey.foregroundColor: theme.titleTextColor]
        if #available(iOS 11.0, *) {
            largeTitleTextAttributes = [NSAttributedStringKey.foregroundColor: theme.titleTextColor]
        }
    }
}

extension UISearchBar {
    
    func initialise(withTheme theme: Theme) {
        keyboardAppearance = theme == .normal ? .default : .dark
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue: theme.titleTextColor]
    }
}

extension UITableView {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.viewBackgroundColor
    }
}

extension UITabBar {
    func initialise(withTheme theme: Theme) {
        barTintColor = theme.viewBackgroundColor
    }
}
