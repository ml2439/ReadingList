import Foundation
import UIKit
import SwiftyJSON

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

public extension NSAttributedString {
    @objc public convenience init(_ string: String, withFont font: UIFont) {
        self.init(string: string, attributes: [NSAttributedStringKey.font: font])
    }
}

extension NSLayoutConstraint {
    static let lowPriority: Float = 250
    static let highPriority: Float = 999
    
    func highPriorityIff(_ condition: Bool) {
        priority = UILayoutPriority(rawValue: condition ? NSLayoutConstraint.highPriority : NSLayoutConstraint.lowPriority)
    }
}

extension UILabel {
    func setTextOrHide(_ text: String?) {
        self.text = text
        self.isHidden = text == nil
    }
}

extension UIApplication {
    func openUrlPlatformSpecific(url: URL, completionHandler: ((Bool) -> Void)? = nil) {
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
        }
        else {
            let result = UIApplication.shared.openURL(url)
            completionHandler?(result)
        }
    }
}

extension NSMutableAttributedString {
    
    @discardableResult func hyperlinkText(_ textToLink: String, to linkURL: URL) -> Bool {
        let foundRange = self.mutableString.range(of: textToLink)
        if foundRange.location != NSNotFound {
            self.addAttribute(NSAttributedStringKey.link, value: linkURL, range: foundRange)
            return true
        }
        return false
    }
    
    convenience init(_ string: String, withFont font: UIFont) {
        self.init(attributedString: NSAttributedString(string, withFont: font))
    }
}

public extension Date {
    init?(dateString: String?) {
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = "yyyy-MM-dd"
        dateStringFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let dateString = dateString, let date = dateStringFormatter.date(from: dateString) else { return nil }
        self.init(timeInterval: 0, since: date)
    }

    func toString(withDateStyle dateStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func toString(withDateFormat dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: self)
    }
    
    static func startOfToday() -> Date {
        return Calendar.current.startOfDay(for: Date())
    }
    
    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    func compareIgnoringTime(_ other: Date) -> ComparisonResult {
        return self.startOfDay().compare(other.startOfDay())
    }
    
    func toPrettyString(short: Bool = true) -> String {
        let today = Date.startOfToday()
        let otherDate = startOfDay()
        
        let thisYear = Calendar.current.dateComponents([.year], from: today).year!
        let otherYear = Calendar.current.dateComponents([.year], from: otherDate).year!
        
        let daysDifference = Calendar.current.dateComponents([.day], from: otherDate, to: today).day!
        
        if daysDifference == 0 {
            return "Today"
        }
        if daysDifference > 0 && daysDifference <= 3 {
            return self.toString(withDateFormat: "EEE\(short ? "" : "E")")
        }
        else {
            // Use the format "12 Feb", or - if the date is not from this year - "12 Feb 2015"
            return self.toString(withDateFormat: "d MMM\(short ? "" : "M")\(thisYear == otherYear ? "" : " yyyy")")
        }
    }
    
    func date(byAdding dateComponents: DateComponents) -> Date? {
        return Calendar.current.date(byAdding: dateComponents, to: self)
    }
}

extension NSData {
    static func fromMainBundle(resource: String, type: String) -> NSData {
        let path = Bundle.main.path(forResource: resource, ofType: type)!
        return try! NSData(contentsOfFile: path)
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

extension JSON {
    init?(optionalData: Data?) {
        if let data = optionalData {
            self.init(data: data)
        }
        else {
            return nil
        }
    }
}

extension URL {
    init?(optionalString: String?) {
        guard let string = optionalString else { return nil }
        self.init(string: string)
    }
    
    func toHttps() -> URL {
        var urlComponents = URLComponents.init(url: self, resolvingAgainstBaseURL: false)!
        urlComponents.scheme = "https"
        return urlComponents.url!
    }
}

extension URLComponents {
    init?(optionalString: String?) {
        guard let string = optionalString else { return nil }
        self.init(string: string)
    }
}

extension Array where Element: Equatable {
    func distinct() -> [Element] {
        var uniqueValues: [Element] = []
        forEach { item in
            if !uniqueValues.contains(item) {
                uniqueValues += [item]
            }
        }
        return uniqueValues
    }
    
    func any(where whereFunc: (Element) -> Bool) -> Bool {
        return first(where: whereFunc) != nil
    }
}

extension String.SubSequence {
    func trimming() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
}

extension String {
    /// Return whether the string contains any characters which are not whitespace.
    var isEmptyOrWhitespace: Bool {
        return self.trimming().isEmpty
    }
    
    func nilIfWhitespace() -> String? {
        return isEmptyOrWhitespace ? nil : self
    }
    
    /// Removes all whitespace characters from the beginning and the end of the string.
    func trimming() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
    
    func toAttributedString(_ attributes: [NSAttributedStringKey: Any]?) -> NSAttributedString {
        return NSAttributedString(string: self, attributes: attributes)
    }
    
    func toAttributedStringWithFont(_ font: UIFont) -> NSAttributedString {
        return self.toAttributedString([NSAttributedStringKey.font: font])
    }
    
    func withTextStyle(_ textStyle: UIFontTextStyle) -> NSAttributedString {
        return self.toAttributedStringWithFont(UIFont.preferredFont(forTextStyle: textStyle))
    }
    
    func toDateViaFormat(_ format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale.current
        return dateFormatter.date(from: self)
    }
    
    func toCsvEscaped() -> String {
        let charactersWhichRequireWrapping = CharacterSet(charactersIn: "\n,")
        let wrapInQuotes = self.rangeOfCharacter(from: charactersWhichRequireWrapping) != nil
        
        // Replace " with ""
        let escapedString = self.replacingOccurrences(of: "\"", with: "\"\"")

        if wrapInQuotes {
           return "\"\(escapedString)\""
        }
        return escapedString
    }
    
    func urlEncoded() -> String {
        let allowedCharacterSet = (CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[] ").inverted)
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)!
    }
}

extension NSPredicate {    
    
    convenience init(boolean: Bool) {
        switch boolean {
        case true:
            self.init(format: "TRUEPREDICATE")
        case false:
            self.init(format: "FALSEPREDICATE")
        }
    }
    
    convenience init(intFieldName: String, equalTo: Int) {
        self.init(format: "\(intFieldName) == %d", equalTo)
    }
    
    convenience init(stringFieldName: String, equalTo: String) {
        self.init(format: "\(stringFieldName) == %@", equalTo)
    }
    
    convenience init(fieldName: String, containsSubstring: String) {
        // Special case for "contains empty string": should return TRUE
        if containsSubstring.isEmpty {
            self.init(boolean: true)
        }
        else {
            self.init(format: "\(fieldName) CONTAINS[cd] %@", containsSubstring)
        }
    }
    
    static func Or(_ orPredicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }
    
    static func And(_ andPredicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }
    
    static func wordsWithinFields(_ searchString: String, fieldNames: String...) -> NSPredicate {
        // Split on whitespace and remove empty elements
        let searchStringComponents = searchString.components(separatedBy: CharacterSet.alphanumerics.inverted).filter{
            !$0.isEmpty
        }
        
        // AND each component, where each component is OR'd over each of the fields
        return NSPredicate.And(searchStringComponents.map{ searchStringComponent in
            NSPredicate.Or(fieldNames.map{ fieldName in
                NSPredicate(fieldName: fieldName, containsSubstring: searchStringComponent)
            })
        })
    }
    
    
    func Or(_ orPredicate: NSPredicate) -> NSPredicate {
        return NSPredicate.Or([self, orPredicate])
    }
    
    
    func And(_ andPredicate: NSPredicate) -> NSPredicate {
        return NSPredicate.And([self, andPredicate])
    }
}
