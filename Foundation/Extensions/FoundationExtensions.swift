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
