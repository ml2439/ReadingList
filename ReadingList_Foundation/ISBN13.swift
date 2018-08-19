import Foundation

public struct ISBN13 {

    public var string: String {
        return String(int)
    }

    public var number: NSNumber {
        return NSNumber(value: int)
    }

    public let int: Int64

    public init?(_ value: Int64) {
        guard ISBN13.isValid(value) else { return nil }
        int = value
    }

    public init?(_ string: String?) {
        guard let sanitisedInput = string?.replacingOccurrences(of: "-", with: ""),
            let parsedInt = Int64(sanitisedInput) else { return nil }

        self.init(parsedInt)
    }

    public static func isValid(_ value: Int64) -> Bool {
        // Early fail if the number is the wrong size
        if value < 9_780_000_000_000 || value >= 9_800_000_000_000 {
            return false
        }

        // The last digit of the number is the check digit.
        let actualCheckDigit = Int(truncatingIfNeeded: value % 10)

        var digitsToBeProcessed: Int64 = value / 10
        var computedCheckValue = 0
        for digitIndex in 1...12 {
            let thisDigit = Int(truncatingIfNeeded: digitsToBeProcessed % 10)
            computedCheckValue += (digitIndex % 2 == 0 ? 1 : 3) * thisDigit
            digitsToBeProcessed /= 10
        }

        computedCheckValue %= 10
        if computedCheckValue != 0 {
            computedCheckValue = 10 - computedCheckValue
        }
        return computedCheckValue == actualCheckDigit
    }
}
