import Foundation

struct UserSetting<SettingType> {
    private let key: String
    private let defaultValue: SettingType
    
    init(key: String, defaultValue: SettingType) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var value: SettingType {
        get {
            guard let settingsObject = UserDefaults.standard.object(forKey: key) else { return defaultValue }
            return settingsObject as! SettingType
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
