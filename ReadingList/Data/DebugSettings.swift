import Foundation

#if DEBUG

    // TODO: Move to using command line switches
    
    
enum BarcodeScanSimulation: Int {
    case none = 0
    case normal = 1
    case noCameraPermissions = 2
    case validIsbn = 3
    case unfoundIsbn = 4
    case existingIsbn = 5
    
    var titleText: String {
        switch self {
        case .none:
            return "None"
        case .normal:
            return "Normal"
        case .noCameraPermissions:
            return "No Camera Permissions"
        case .validIsbn:
            return "Valid ISBN"
        case .unfoundIsbn:
            return "Not-found ISBN"
        case .existingIsbn:
            return "Existing ISBN"
        }
    }
}

enum QuickAction: Int {
    case none = 0
    case barcodeScan = 1
    case searchOnline = 2
    
    var titleText: String {
        switch self {
        case .none:
            return "None"
        case .barcodeScan:
            return "Barcode Scan"
        case .searchOnline:
            return "Search Online"
        }
    }
}

class DebugSettings {
    private static let useFixedBarcodeScanImageKey = "useFixedBarcodeScanImage"
    
    /**
     This string should be an ISBN which is included in the test debug import data.
    */
    static let existingIsbn = "9780547345666"
    
    static var useFixedBarcodeScanImage: Bool {
        get {
            return (UserDefaults.standard.value(forKey: useFixedBarcodeScanImageKey) as? Bool) ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: useFixedBarcodeScanImageKey)
        }
    }
    
    private static let barcodeScanSimulationKey = "barcodeScanSimulation"
    
    static var barcodeScanSimulation: BarcodeScanSimulation {
        get {
            guard let rawValue = UserDefaults.standard.value(forKey: barcodeScanSimulationKey) as? Int else { return .none }
            return BarcodeScanSimulation.init(rawValue: rawValue)!
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: barcodeScanSimulationKey)
        }
    }
    
    private static let showSortNumberKey = "showSortNumber"
    
    static var showSortNumber: Bool {
        get {
            return UserDefaults.standard.value(forKey: showSortNumberKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: showSortNumberKey)
        }
    }
    
    private static let showCellReloadControlKey = "showCellReloadControl"
    
    static var showCellReloadControl: Bool {
        get {
            return UserDefaults.standard.value(forKey: showCellReloadControlKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: showCellReloadControlKey)
        }
    }
    
    private static let quickActionSimulationKey = "quickActionSimulation"
    
    static var quickActionSimulation: QuickAction {
        get {
            guard let simulation = UserDefaults.standard.value(forKey: quickActionSimulationKey) as? Int else { return .none }
            return QuickAction(rawValue: simulation)!
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: quickActionSimulationKey)
        }
    }
}

#endif
