import Foundation

class Isbn13 {
    
    static func tryParse(inputString: String?) -> String? {
        guard let inputString = inputString else { return nil }
        
        let sanitisedInput = inputString.replacingOccurrences(of: "-", with: "")
        guard sanitisedInput.count == 13, sanitisedInput.hasPrefix("978") || sanitisedInput.hasPrefix("979"),
            let _ = Int64.init(sanitisedInput) else {
            return nil
        }
        
        // Comment Source: Wikipedia
        // The calculation of an ISBN-13 check digit begins with the first
        // 12 digits of the thirteen-digit ISBN (thus excluding the check digit itself).
        // Each digit, from left to right, is alternately multiplied by 1 or 3,
        // then those products are summed modulo 10 to give a value ranging from 0 to 9.
        // Subtracted from 10, that leaves a result from 1 to 10. A zero (0) replaces a
        // ten (10), so, in all cases, a single check digit results.
        var sum = 0
        for (index, character) in sanitisedInput.enumerated() {
            guard let thisDigit = Int(string: String(character)) else {
                return nil
            }
            if index == 12 {
                let remainer = sum % 10
                let checkDigit = remainer == 0 ? 0 : 10 - remainer
                if Int(string: String(character)) != checkDigit {
                    return nil
                }
            }
            else {
                sum += (index % 2 == 1 ? 3 : 1) * thisDigit
            }
        }
        
        return sanitisedInput
    }
}
