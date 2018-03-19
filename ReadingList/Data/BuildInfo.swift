import Foundation

class BuildInfo {
    enum BuildType {
        case debug
        case testFlight
        case appStore
    }
    
    static var appVersion: String {
        get { return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String }
    }

    static var appBuildNumber: String {
        get { return Bundle.main.infoDictionary!["CFBundleVersion"] as! String }
    }

    private static let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    static var isDebug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    static var appConfiguration: BuildType {
        if isDebug {
            return .debug
        }
        else if isTestFlight {
            return .testFlight
        }
        else {
            return .appStore
        }
    }
}

extension BuildInfo.BuildType {
    var userFacingDescription: String {
        switch BuildInfo.appConfiguration {
        case .appStore: return "v\(BuildInfo.appVersion)"
        case .testFlight: return "v\(BuildInfo.appVersion) beta\(BuildInfo.appBuildNumber))"
        case .debug: return "v\(BuildInfo.appVersion) debug"
        }
    }
}
