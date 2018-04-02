import UIKit
import Foundation
import Eureka
import ImageRow
import SafariServices

@objc enum Theme: Int {
    case normal = 1
    case dark = 2
    case black = 3
}

extension Theme {
    var keyboardAppearance: UIKeyboardAppearance {
        return self == .normal ? .default : .dark
    }
    
    var barStyle: UIBarStyle {
        return self == .normal ? .default : .black
    }
    
    var placeholderTextColor: UIColor {
        return subtitleTextColor // TODO: This might be too light
    }
    
    var titleTextColor: UIColor {
        return self == .normal ? .black : .white
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
    
    var selectedCellBackgroundColor: UIColor {
        return tableSeparatorColor
    }
    
    var viewBackgroundColor: UIColor {
        switch self {
        case .normal: return .white
        case .dark: return UIColor(fromHex: 0x2d3038)
        case .black: return .black
        }
    }
    
    var tableBackgroundColor: UIColor {
        return self == .normal ? .groupTableViewBackground : viewBackgroundColor
    }

    var tableSeparatorColor: UIColor {
        switch self {
        case .normal: return UIColor(displayP3Red: 0.783922, green: 0.780392, blue: 0.8, alpha: 1)
        case .dark: return .darkGray
        case .black: return .veryDarkGray
        }
    }
}

extension UITableViewCell {
    func defaultInitialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
        detailTextLabel?.textColor = theme.titleTextColor
        selectedBackgroundColor = theme.selectedCellBackgroundColor
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

extension UIViewController {
    func presentThemedSafariViewController(url: String) {
        self.presentThemedSafariViewController(url: URL(string: url)!)
    }
    
    func presentThemedSafariViewController(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        if UserSettings.theme != .normal {
            safariVC.preferredBarTintColor = .black
        }
        self.present(safariVC, animated: true, completion: nil)
    }
}

extension UITabBarController: ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        tabBar.initialise(withTheme: theme)
    }
}

extension UIToolbar {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.viewBackgroundColor
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
        let selectedRow = tableView.indexPathForSelectedRow
        if let selectedRow = selectedRow { tableView.deselectRow(at: selectedRow, animated: false) }
        tableView.reloadData()
        if let selectedRow = selectedRow { tableView.selectRow(at: selectedRow, animated: false, scrollPosition: .none) }
    }
}

extension FormViewController: ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        tableView.initialise(withTheme: theme)
    }
    
    func themeSettingDidChange() {
        // Saw some weird artifacts which went away when the selected rows were deselected
        let selectedRow = tableView.indexPathForSelectedRow
        if let selectedRow = selectedRow { tableView.deselectRow(at: selectedRow, animated: false) }
        tableView.reloadData()
        if let selectedRow = selectedRow { tableView.selectRow(at: selectedRow, animated: false, scrollPosition: .none) }
    }
}

class ThemedSplitViewController: UISplitViewController, UISplitViewControllerDelegate, ThemeableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredDisplayMode = .allVisible
        delegate = self
        monitorThemeSetting()
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    func initialise(withTheme theme: Theme) { }
    
    func themeSettingDidChange() {
        configureBarTranslucency()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            configureBarTranslucency()
        }
    }
    
    func configureBarTranslucency() {
        // This attempts to allieviate this bug: https://stackoverflow.com/q/32507975/5513562
        // When the barTintColor is set, the translucency is reduced. This is far easier than dealing with all
        // the side affects of setting isTranslucent to false.
        let reduceTranslucency = traitCollection.horizontalSizeClass == .regular
        masterNavigationController.navigationBar.barTintColor = reduceTranslucency ? UserSettings.theme.viewBackgroundColor : nil
        tabBarController!.tabBar.barTintColor = reduceTranslucency ? UserSettings.theme.viewBackgroundColor : nil
    }
}

class ThemedNavigationController: UINavigationController, ThemeableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        monitorThemeSetting()
    }

    func initialise(withTheme theme: Theme) {
        self.navigationBar.initialise(withTheme: theme)
        self.toolbar?.initialise(withTheme: theme)
    }
}

extension UINavigationBar {
    func initialise(withTheme theme: Theme) {
        barStyle = theme.barStyle
        titleTextAttributes = [NSAttributedStringKey.foregroundColor: theme.titleTextColor]
        if #available(iOS 11.0, *) {
            largeTitleTextAttributes = [NSAttributedStringKey.foregroundColor: theme.titleTextColor]
        }
    }
}

extension UISearchBar {
    func initialise(withTheme theme: Theme) {
        keyboardAppearance = theme.keyboardAppearance
        barStyle = theme.barStyle
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue: theme.titleTextColor]
    }
}

extension UITableView {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.tableBackgroundColor
        separatorColor = theme.tableSeparatorColor
        sectionIndexColor = theme.subtitleTextColor
        if let searchBar = tableHeaderView as? UISearchBar {
            searchBar.initialise(withTheme: theme)
        }
    }
}

extension UITabBar {
    func initialise(withTheme theme: Theme) {
        barStyle = theme.barStyle
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
        selectedBackgroundColor = theme.selectedCellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
    }
}

extension ButtonCellOf {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        selectedBackgroundColor = theme.selectedCellBackgroundColor
    }
}

extension IntCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        selectedBackgroundColor = theme.selectedCellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
        textField.textColor = theme.titleTextColor
        textField.keyboardAppearance = theme.keyboardAppearance
    }
}

extension TextAreaCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textView.backgroundColor = theme.cellBackgroundColor
        textView.textColor = theme.titleTextColor
        placeholderLabel?.textColor = theme.placeholderTextColor
        textView.keyboardAppearance = theme.keyboardAppearance
    }
}

extension TextRow {
    static func initialise(_ textCell: TextCell, _ textRow: TextRow) {
        let theme = UserSettings.theme
        textCell.backgroundColor = theme.cellBackgroundColor
        textCell.textField.textColor = theme.titleTextColor
        textCell.textField.keyboardAppearance = theme.keyboardAppearance
        textCell.textLabel?.textColor = theme.titleTextColor
        textRow.placeholderColor = theme.placeholderTextColor
    }
}

extension SegmentedCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
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
        selectedBackgroundColor = theme.selectedCellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
    }
}

extension ListCheckCell {
    func initialise(withTheme theme: Theme) {
        backgroundColor = theme.cellBackgroundColor
        textLabel?.textColor = theme.titleTextColor
        selectedBackgroundColor = theme.selectedCellBackgroundColor
    }
}
