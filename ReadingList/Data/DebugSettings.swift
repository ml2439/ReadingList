#if DEBUG

import Foundation

class DebugSettings {

    private static let showSortNumberKey = "showSortNumber"

    static var showSortNumber: Bool {
        get {
            return UserDefaults.standard.value(forKey: showSortNumberKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: showSortNumberKey)
        }
    }
}

#endif
