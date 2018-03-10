import Foundation

extension UserDefaults {
    func incrementCounter(withKey key: String) {
        let newCount = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(newCount, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    func getCount(withKey: String) -> Int {
        return UserDefaults.standard.integer(forKey: withKey)
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
    
    func urlEncoding() -> String {
        let allowedCharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[] ").inverted
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)!
    }
    
    var sortable: String {
        get { return self.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale.current) }
    }
}

extension Int {
    var string: String {
        get { return String(describing: self) }
    }
    
    init?(_ string: String?) {
        guard let str = string else { return nil }
        self.init(str)
    }
    
    var nsNumber: NSNumber {
        return NSNumber(integerLiteral: self)
    }
}

extension Int32 {
    var nsNumber: NSNumber {
        return NSNumber(value: self)
    }
}

extension NSNumber {
    var int32: Int32 {
        return Int32(truncating: self)
    }
}

extension NSSortDescriptor {
    convenience init<Root, Value>(_ keyPath: KeyPath<Root, Value>, ascending: Bool = true) {
        self.init(keyPath: keyPath, ascending: ascending)
    }
    
    convenience init(_ key: String, ascending: Bool = true) {
        self.init(key: key, ascending: ascending)
    }
}

extension URL {
    static func temporary() -> URL {
        return URL(fileURLWithPath:NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    }

    static var documents: URL {
        return try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    static var applicationSupport: URL {
        return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

extension String.SubSequence {
    func trimming() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
}

extension FileManager {
    func removeTemporaryFiles() {
        let tmpFiles: [URL]
        do {
            tmpFiles = try FileManager.default.contentsOfDirectory(at: URL(string: NSTemporaryDirectory())!, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        }
        catch {
            print("Error enumerating temporary directory: \(error)")
            return
        }
        
        for url in tmpFiles {
            do {
                try FileManager.default.removeItem(at: url)
                print("Removed temporary file: \(url.path)")
            }
            catch {
                print("Unable to remove temporary file: \(url.path)")
            }
        }
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

extension Date {
    init?(iso: String?) {
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = "yyyy-MM-dd"
        dateStringFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let iso = iso, let date = dateStringFormatter.date(from: iso) else { return nil }
        self.init(timeInterval: 0, since: date)
    }
    
    func string(withDateFormat dateFormat: String) -> String {
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
    
    func date(byAdding dateComponents: DateComponents) -> Date? {
        return Calendar.current.date(byAdding: dateComponents, to: self)
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
            return self.string(withDateFormat: "EEE\(short ? "" : "E")")
        }
        else {
            // Use the format "12 Feb", or - if the date is not from this year - "12 Feb 2015"
            return self.string(withDateFormat: "d MMM\(short ? "" : "M")\(thisYear == otherYear ? "" : " yyyy")")
        }
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
    
    convenience init(fieldName: String, containsSubstring substring: String) {
        // Special case for "contains empty string": should return TRUE
        if substring.isEmpty {
            self.init(boolean: true)
        }
        else {
            self.init(format: "\(fieldName) CONTAINS[cd] %@", substring)
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
}
