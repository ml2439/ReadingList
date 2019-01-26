import Foundation
import ReadingList_Foundation

class BuildInfo {
    enum BuildType {
        case debug
        case testFlight
        case appStore
    }

    static var appVersion: String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }

    static var appBuildNumber: String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    }

    static var version: Version {
        let components = appVersion.split(separator: ".").compactMap { Int(String($0)) }
        guard components.count == 3 else { preconditionFailure("Unexpected format of appVersion string") }
        return Version(components[0], components[1], components[2])
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
        } else if isTestFlight {
            return .testFlight
        } else {
            return .appStore
        }
    }
}

extension BuildInfo.BuildType {
    var fullDescription: String {
        switch BuildInfo.appConfiguration {
        case .appStore: return "\(BuildInfo.appVersion)"
        case .testFlight: return "\(BuildInfo.appVersion) (Build \(BuildInfo.appBuildNumber))"
        case .debug: return "\(BuildInfo.appVersion) Debug"
        }
    }

    var versionAndConfiguration: String {
        switch BuildInfo.appConfiguration {
        case .appStore: return BuildInfo.appVersion
        case .testFlight: return "\(BuildInfo.appVersion) (Beta)"
        case .debug: return "\(BuildInfo.appVersion) (Debug)"
        }
    }
}
