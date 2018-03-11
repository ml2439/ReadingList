import Foundation
import UIKit

extension UINib {
    convenience init<T>(_ class: T.Type) where T : UIView {
        self.init(nibName: String(describing: T.self), bundle: nil)
    }
    
    static func instantiate<T>(_ class: T.Type) -> T where T : UIView {
        return UINib(T.self).instantiate(withOwner: nil, options: nil)[0] as! T
    }
}

extension UIView {
    @IBInspectable var maskedCornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    convenience init(backgroundColor: UIColor) {
        self.init()
        self.backgroundColor = backgroundColor
    }
}


extension UIStoryboard {
    func instantiateRoot(withStyle style: UIModalPresentationStyle? = nil) -> UIViewController {
        let vc = self.instantiateInitialViewController()!
        if let style = style {
            vc.modalPresentationStyle = style
        }
        return vc
    }
    
    func rootAsFormSheet() -> UIViewController {
        return instantiateRoot(withStyle: .formSheet)
    }
}

@available(iOS 11.0, *)
extension UISwipeActionsConfiguration {
    convenience init(performFirstActionWithFullSwipe: Bool, actions: [UIContextualAction]) {
        self.init(actions: actions)
        self.performsFirstActionWithFullSwipe = performFirstActionWithFullSwipe
    }
}

extension UISearchController {
    convenience init(filterPlaceholderText: String) {
        self.init(searchResultsController: nil)
        dimsBackgroundDuringPresentation = false
        searchBar.returnKeyType = .done
        searchBar.placeholder = filterPlaceholderText
        searchBar.searchBarStyle = .default
    }
    
    var hasActiveSearchTerms: Bool {
        return self.isActive && self.searchBar.text?.isEmpty == false
    }
}

extension UIViewController {
    func inNavigationController(modalPresentationStyle: UIModalPresentationStyle = .formSheet) -> UINavigationController {
        let nav = UINavigationController(rootViewController: self)
        nav.modalPresentationStyle = modalPresentationStyle
        return nav
    }
}

extension UINavigationController {
    func dismissAndPopToRoot() {
        dismiss(animated: false)
        popToRootViewController(animated: false)
    }
}

extension UIPopoverPresentationController {
    
    func setSourceCell(_ cell: UITableViewCell, inTableView tableView: UITableView, arrowDirections: UIPopoverArrowDirection = .any) {
        self.sourceRect = cell.frame
        self.sourceView = tableView
        self.permittedArrowDirections = arrowDirections
    }
    
    func setSourceCell(atIndexPath indexPath: IndexPath, inTable tableView: UITableView, arrowDirections: UIPopoverArrowDirection = .any) {
        let cell = tableView.cellForRow(at: indexPath)!
        setSourceCell(cell, inTableView: tableView, arrowDirections: arrowDirections)
    }
}

extension UIActivityType {
    static var documentUnsuitableTypes: [UIActivityType] {
        get {
            var types: [UIActivityType] = [addToReadingList, assignToContact, saveToCameraRoll, postToFlickr, postToVimeo,
                                           postToTencentWeibo, postToTwitter, postToFacebook, openInIBooks]
            if #available(iOS 11.0, *) {
                types.append(.markupAsPDF)
            }
            return types
        }
    }
}

extension UISearchBar {
    var isActive: Bool {
        get {
            return isUserInteractionEnabled
        }
        set {
            isUserInteractionEnabled = newValue
            alpha = newValue ? 1.0 : 0.5
        }
    }
    
    var isActiveOrVisible: Bool {
        get {
            if #available(iOS 11.0, *) {
                return isActive
            }
            else {
                return !isHidden
            }
        }
        set {
            // iOS >10 search bars can be made hidden without much consequence;
            // iOS 11 search bars are part of navigation items, which makes hiding them look weird. Instead we "disable" them.
            if #available(iOS 11.0, *) {
                isActive = newValue
            }
            else {
                isHidden = !newValue
            }
        }
    }
}

extension UIBarButtonItem {
    func toggleHidden(hidden: Bool) {
        isEnabled = !hidden
        tintColor = hidden ? UIColor.clear : nil
    }
}

extension UIScrollView {
    var universalContentInset: UIEdgeInsets {
        get {
            if #available(iOS 11.0, *) {
                return adjustedContentInset
            }
            else {
                return contentInset
            }
        }
    }
}

extension UILabel {
    var isTruncated: Bool {
        guard let labelText = text else { return false }
        let labelTextSize = (labelText as NSString).boundingRect(
            with: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [NSAttributedStringKey.font: font],
            context: nil).size
        return labelTextSize.height > bounds.size.height
    }
    
    func setTextOrHide(_ text: String?) {
        self.text = text
        self.isHidden = text == nil
    }
    
    @IBInspectable var dynamicFontSize: String? {
        get {
            return nil
        }
        set {
            guard let newValue = newValue else { return }
            font = font.scaled(forTextStyle: UIFontTextStyle("UICTFontTextStyle\(newValue)"))
        }
    }
}

extension UIColor {
    convenience init(fromHex hex: UInt32){
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    static let flatGreen: UIColor = UIColor(fromHex: 0x2ecc71)
    static let darkGray: UIColor = UIColor(fromHex: 0x4A4A4A)
    static let buttonBlue = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
}

extension UIFont {
    static let gillSans = UIFont(name: "GillSans", size: 12)!
    static let gillSansSemiBold = UIFont(name: "GillSans-Semibold", size: 12)!
    
    static func gillSans(ofSize: CGFloat) -> UIFont {
        return gillSans.withSize(ofSize)
    }
        
    static func gillSans(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        return gillSans.scaled(forTextStyle: textStyle)
    }
        
    static func gillSansSemiBold(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        return gillSansSemiBold.scaled(forTextStyle: textStyle)
    }
    
    func scaled(forTextStyle textStyle: UIFontTextStyle) -> UIFont {
        let fontSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        return self.withSize(fontSize)
    }
}

extension UIImage {
    convenience init?(optionalData: Data?) {
        if let data = optionalData {
            self.init(data: data)
        }
        else {
            return nil
        }
    }
}


public extension NSAttributedString {
    @objc public convenience init(_ string: String, withFont font: UIFont) {
        self.init(string: string, attributes: [NSAttributedStringKey.font: font])
    }
    
    static func createFromMarkdown(_ markdown: String, font: UIFont, boldFont: UIFont) -> NSMutableAttributedString {
        let boldedResult = NSMutableAttributedString()
        for (index, component) in markdown.components(separatedBy: "**").enumerated() {
            boldedResult.append(NSAttributedString(component, withFont: index % 2 == 0 ? font : boldFont))
        }
        return boldedResult
    }
}

extension UITableView {
    func advisedFetchBatchSize(forTypicalCell cell: UITableViewCell) -> Int {
        return Int((self.frame.height / cell.frame.height) * 1.3)
    }
}

extension UITableViewCell {
    var isEnabled: Bool {
        get {
            return isUserInteractionEnabled && textLabel?.isEnabled != false && detailTextLabel?.isEnabled != false
        }
        set {
            isUserInteractionEnabled = newValue
            textLabel?.isEnabled = newValue
            detailTextLabel?.isEnabled = newValue
        }
    }
}

extension UIDevice {
    
    // From https://stackoverflow.com/a/26962452/5513562
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    var modelName: String {
        let identifier = modelIdentifier
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
        case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":                return "iPhone X"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad6,11", "iPad6,12":                    return "iPad 5"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7 Inch"
        case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9 Inch"
        case "iPad7,1", "iPad7,2":                      return "iPad Pro 12.9 Inch (2nd Generation)"
        case "iPad7,3", "iPad7,4":                      return "iPad Pro 10.5 Inch"
        case "AppleTV5,3":                              return "Apple TV"
        case "AppleTV6,2":                              return "Apple TV 4K"
        case "AudioAccessory1,1":                       return "HomePod"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
}
