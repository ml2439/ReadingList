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
            return UserDefaults.standard.object(forKey: key) as? SettingType ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
