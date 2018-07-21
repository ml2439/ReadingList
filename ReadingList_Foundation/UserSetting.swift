import Foundation

public struct UserSetting<SettingType> {
    private let key: String
    private let defaultValue: SettingType

    public init(key: String, defaultValue: SettingType) {
        self.key = key
        self.defaultValue = defaultValue
    }

    public var value: SettingType {
        get {
            guard let settingsObject = UserDefaults.standard.object(forKey: key) else { return defaultValue }
            return settingsObject as! SettingType
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

public struct WrappedUserSetting<SettingType: RawRepresentable> {
    private let key: String
    private let defaultValue: SettingType

    public init(key: String, defaultValue: SettingType) {
        self.key = key
        self.defaultValue = defaultValue
    }

    public var value: SettingType {
        get {
            guard let settingsObject = UserDefaults.standard.object(forKey: key) else { return defaultValue }
            return SettingType(rawValue: settingsObject as! SettingType.RawValue)!
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
