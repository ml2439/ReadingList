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

extension UIColor {
    static var customHexColorCache = [UInt32: UIColor]()
    
    static func hex(_ hex: UInt32) -> UIColor {
        if let cachedColor = UIColor.customHexColorCache[hex] { return cachedColor }
        let color = UIColor(fromHex: hex)
        customHexColorCache[hex] = color
        return color
    }
}

extension Theme {
    var isDark: Bool {
        return self == .dark || self == .black
    }
    
    var keyboardAppearance: UIKeyboardAppearance {
        return isDark ? .dark : .default
    }
    
    var barStyle: UIBarStyle {
        return isDark ? .black : .default
    }
    
    var titleTextColor: UIColor {
        return isDark ? .white : .black
    }
    
    var subtitleTextColor: UIColor {
        switch self {
        case .normal: return UIColor.hex(0x686868)
        case .dark: return .lightGray
        case .black: return .lightGray
        }
    }
    
    var placeholderTextColor: UIColor {
        switch self {
        case .normal: return UIColor.hex(0xCDCDD3)
        case .dark: return UIColor.hex(0x303030)
        case .black: return UIColor.hex(0x262626)
        }
    }
    
    var tableBackgroundColor: UIColor {
        switch self {
        case .normal: return .groupTableViewBackground
        case .dark: return UIColor.hex(0x282828)
        case .black: return UIColor.hex(0x080808)
        }
    }
    
    var cellBackgroundColor: UIColor {
        return viewBackgroundColor
    }
    
    var selectedCellBackgroundColor: UIColor {
        switch self {
        case .normal: return UIColor.hex(0xD9D9D9)
        case .dark: return .black
        case .black: return UIColor.hex(0x191919)
        }
    }
    
    var cellSeparatorColor: UIColor {
        switch self {
        case .normal: return UIColor.hex(0xD6D6D6)
        case .dark: return UIColor.hex(0x4A4A4A)
        case .black: return UIColor.hex(0x282828)
        }
    }
    
    var viewBackgroundColor: UIColor {
        switch self {
        case .normal: return .white
        case .dark: return UIColor.hex(0x191919)
        case .black: return .black
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

fileprivate extension UIViewController {
    /**
     Must only called on a ThemableViewController.
    */
    @objc func transitionThemeChange() {
        // This function is defined as an extension of UIViewController rather than in ThemableViewController
        // since it must be @objc, and that is not possible in protocol extensions.
        guard let themable = self as? ThemeableViewController else { fatalError("transitionThemeChange called on a non-themable controller") }
        UIView.transition(with: self.view, duration: 0.3, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: {
            themable.initialise(withTheme: UserSettings.theme.value)
            themable.themeSettingDidChange?()
        }, completion: nil)
    }
}

@objc protocol ThemeableViewController where Self: UIViewController {
    @objc func initialise(withTheme theme: Theme)
    @objc optional func themeSettingDidChange()
}

extension ThemeableViewController {
    func monitorThemeSetting() {
        initialise(withTheme: UserSettings.theme.value)
        NotificationCenter.default.addObserver(self, selector: #selector(transitionThemeChange), name: NSNotification.Name.ThemeSettingChanged, object: nil)
    }
}

extension UIViewController {
    func presentThemedSafariViewController(url: String) {
        presentThemedSafariViewController(url: URL(string: url)!)
    }
    
    func presentThemedSafariViewController(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        if UserSettings.theme.value.isDark {
            safariVC.preferredBarTintColor = .black
        }
        present(safariVC, animated: true, completion: nil)
    }
}

extension UITabBarController: ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        tabBar.initialise(withTheme: theme)

        let useTranslucency = traitCollection.horizontalSizeClass != .regular
        tabBar.setTranslucency(useTranslucency, colorIfNotTranslucent: theme.viewBackgroundColor)
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // This is called at app startup
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            initialise(withTheme: UserSettings.theme.value)
        }
    }
    
    func initialise(withTheme theme: Theme) {
        view.backgroundColor = theme.cellSeparatorColor
        
        // This attempts to allieviate this bug: https://stackoverflow.com/q/32507975/5513562
        (masterNavigationController as! ThemedNavigationController).initialise(withTheme: theme)
        (detailNavigationController as? ThemedNavigationController)?.initialise(withTheme: theme)
        (tabBarController as! TabBarController).initialise(withTheme: theme)
    }
}

class ThemedNavigationController: UINavigationController, ThemeableViewController {
    var hasAppeared = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Determine whether the nav bar should be transparent or not from the horizontal
        // size class of the parent split view controller. We can't ask *this* view controller,
        // as its size class is not necessarily the same as the whole app.
        // Run this after the view has loaded so that the parent VC is available.
        if !hasAppeared {
            monitorThemeSetting()
            hasAppeared = true
        }
    }

    func initialise(withTheme theme: Theme) {
        toolbar?.initialise(withTheme: theme)
        navigationBar.initialise(withTheme: theme)
        
        let translucent = splitViewController?.traitCollection.horizontalSizeClass != .regular
        navigationBar.setTranslucency(translucent, colorIfNotTranslucent: UserSettings.theme.value.viewBackgroundColor)
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
    
    func setTranslucency(_ translucent: Bool, colorIfNotTranslucent: UIColor) {
        isTranslucent = translucent
        barTintColor = translucent ? nil : colorIfNotTranslucent
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
        separatorColor = theme.cellSeparatorColor
        if let searchBar = tableHeaderView as? UISearchBar {
            searchBar.initialise(withTheme: theme)
        }
    }
}

extension UITabBar {
    func initialise(withTheme theme: Theme) {
        barStyle = theme.barStyle
    }
    
    func setTranslucency(_ translucent: Bool, colorIfNotTranslucent: UIColor) {
        isTranslucent = translucent
        barTintColor = translucent ? nil : colorIfNotTranslucent
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
        let theme = UserSettings.theme.value
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
