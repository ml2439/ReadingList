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
}

extension String.SubSequence {
    func trimming() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
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

public extension Date {
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
