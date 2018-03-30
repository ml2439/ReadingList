import UIKit
import Foundation
import Eureka
import ImageRow

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
    
    var tintColor: UIColor {
        return self == .normal ? .buttonBlue : .red
    }
    
    var placeholderTextColor: UIColor {
        return subtitleTextColor
    }
    
    var subtitleTextColor: UIColor {
        switch self {
        case .normal: return .darkGray
        case .dark: return .lightGray
        case .black: return .lightGray
        }
    }
    
    var cellBackgroundColor: UIColor {
        switch self {
        case .normal: return .white
        case .dark: return UIColor(fromHex: 0x22252e)
        case .black: return .black
        }
    }
    
    var tableBackgroundColor: UIColor {
        switch self {
        case .normal: return .groupTableViewBackground
        case .dark: return UIColor(fromHex: 0x2d3038)
        case .black: return .black
        }
    }
    
    var viewBackgroundColor: UIColor {
        switch self {
        case .normal: return .white
        case .dark: return UIColor(fromHex: 0x2d3038)
        case .black: return .black
        }
    }
    
    var navigationBarColor: UIColor {
        return cellBackgroundColor
        /*switch self {
        case .normal: return .white
        case .dark: return UIColor(fromHex: 0x20242b)
        case .black: return .black
        }*/
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
            UIView.transition(with: self.view, duration: 0.3, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: {
                self.initialise(withTheme: UserSettings.theme)
                self.themeSettingDidChange?()
            }, completion: nil)
        }
    }
}

@objc protocol ThemeableViewController where Self: UIViewController {
    @objc func initialise(withTheme theme: Theme)
    @objc optional func themeSettingDidChange()
}

extension UITabBarController: ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        tabBar.initialise(withTheme: theme)
    }
}

extension UITableViewController: ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        if #available(iOS 11.0, *) {
            navigationItem.searchController?.searchBar.initialise(withTheme: theme)
        }
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
    func initialise(withTheme theme: Theme) {
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
    
    func initialise(withTheme theme: Theme) {
        navigationBar.initialise(withTheme: theme)
    }
}

extension UINavigationBar {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.navigationBarColor
        barTintColor = theme.navigationBarColor
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
        backgroundColor = theme.tableBackgroundColor
        //separatorColor = theme.cellBackgroundColor
        if let searchBar = tableHeaderView as? UISearchBar {
            //searchBar.barStyle = theme == .normal ? .default : .black
            searchBar.backgroundColor = theme.tableBackgroundColor
            searchBar.barTintColor = theme.tableBackgroundColor
            searchBar.keyboardAppearance = theme.keyboardAppearance
        }
    }
}

extension UITabBar {
    func initialise(withTheme theme: Theme) {
        barTintColor = theme.navigationBarColor
    }
}

extension SwitchCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
    }
}

extension DateCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
    }
}

extension ButtonCellOf {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
    }
}

extension IntCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
        textField.textColor = theme.titleTextColor
    }
}

extension TextAreaCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textView.backgroundColor = theme.cellBackgroundColor
        textView.textColor = theme.titleTextColor
        //textLabel?.textColor = theme.titleTextColor
        placeholderLabel?.textColor = theme.placeholderTextColor
    }
}

extension TextCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textField.textColor = theme.titleTextColor
        textLabel?.textColor = theme.titleTextColor
    }
}

extension LabelCellOf {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
    }
}

extension ImageCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
    }
}

final class ThemedListCheckRow<T>: Row<ListCheckCell<T>>, SelectableRowType, RowType where T: Equatable {
    public var selectableValue: T?
    required public init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = nil
        self.cellUpdate{ cell,_ in
            cell.backgroundColor = UserSettings.theme.cellBackgroundColor
            cell.textLabel?.textColor = UserSettings.theme.titleTextColor
        }
    }
}
