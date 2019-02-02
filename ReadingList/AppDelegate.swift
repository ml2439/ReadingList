import UIKit
import SVProgressHUD
import SwiftyStoreKit
import CoreData
import ReadingList_Foundation
import os.log

var appDelegate: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var storeMigrationFailed = false

    var tabBarController: TabBarController {
        return window!.rootViewController as! TabBarController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        Debug.initialiseSettings()
        #endif

        UserEngagement.initialiseUserAnalytics()
        SVProgressHUD.setDefaults()
        SwiftyStoreKit.completeTransactions()
        UpgradeActionApplier().performUpgrade()

        // Grab any options which we take action on after the persistent store is initialised
        let quickAction: QuickAction?
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            quickAction = QuickAction(rawValue: shortcut.type)
        } else {
            quickAction = nil
        }
        let csvFileUrl = launchOptions?[.url] as? URL

        initialisePersistentStore {
            // Once the store is loaded and the main storyboard instantiated, perform the shortcut action
            // or open the CSV file, is specified. This is done here rather than in application:open,
            // for example, in the case where the app is not yet launched.
            if let quickAction = quickAction {
                quickAction.perform(from: self.tabBarController)
            } else if let csvFileUrl = csvFileUrl {
                self.openCsvImport(url: csvFileUrl)
            }
        }

        // If there was a QuickAction or URL-open, it is handled here, so prevent another handler from being called
        return quickAction == nil && csvFileUrl == nil
    }

    /**
     Initialises the persistent store on a background thread. If successfully completed, the main thread
     will instantiate the root view controller, perform some other app-startup work, and call the callback.
     If the persistent store fails to initialise, then an error alert is presented to the user.
    */
    private func initialisePersistentStore(onSuccess: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try PersistentStoreManager.initalisePersistentStore {
                    os_log("Persistent store loaded", type: .info)
                    DispatchQueue.main.async {
                        #if DEBUG
                        Debug.initialiseData()
                        #endif
                        self.window!.rootViewController = TabBarController()

                        // Initialise app-level theme, and monitor the set theme
                        self.initialiseTheme()
                        NotificationCenter.default.addObserver(self, selector: #selector(self.initialiseTheme),
                                                               name: .ThemeSettingChanged, object: nil)
                        UserDefaults.standard[.mostRecentWorkingVersion] = BuildInfo.appConfiguration.fullDescription

                        onSuccess?()
                    }
                }
            } catch MigrationError.incompatibleStore {
                DispatchQueue.main.async {
                    self.storeMigrationFailed = true
                    self.presentIncompatibleDataAlert()
                }
            } catch {
                UserEngagement.logError(error)
                fatalError(error.localizedDescription)
            }
        }
    }

    func presentIncompatibleDataAlert() {
        #if RELEASE
        // This is a common error during development, but shouldn't occur in production
        guard UserDefaults.standard[.mostRecentWorkingVersion] != BuildInfo.appConfiguration.fullDescription else {
            UserEngagement.logError(NSError(code: .invalidMigration, userInfo: ["mostRecentWorkingVersion": UserDefaults.standard[.mostRecentWorkingVersion] ?? "unknown"]))
            preconditionFailure("Migration error thrown for store of same version.")
        }
        #endif

        guard window!.rootViewController?.presentedViewController == nil else { return }

        let compatibilityVersionMessage: String?
        if let mostRecentWorkingVersion = UserDefaults.standard[.mostRecentWorkingVersion] {
            compatibilityVersionMessage = """
                \n\nYou previously had version \(mostRecentWorkingVersion), but now have version \
                \(BuildInfo.appConfiguration.fullDescription). You will need to install \
                \(mostRecentWorkingVersion) again to be able to access your data.
                """
        } else {
            UserEngagement.logError(NSError(code: .noPreviousStoreVersionRecorded))
            compatibilityVersionMessage = nil
            assertionFailure("No recorded previously working version")
        }

        let alert = UIAlertController(title: "Incompatible Data", message: """
            The data on this device is not compatible with this version of Reading List.\(compatibilityVersionMessage ?? "")
            """, preferredStyle: .alert)

        #if DEBUG
        alert.addAction(UIAlertAction(title: "Delete Store", style: .destructive) { _ in
            NSPersistentStoreCoordinator().destroyAndDeleteStore(at: URL.applicationSupport.appendingPathComponent(PersistentStoreManager.storeFileName))
            self.initialisePersistentStore()
        })
        #endif

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        window!.rootViewController!.present(alert, animated: true)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
        if let simulatedQuickAction = UserDefaults.standard[.quickActionSimulation] {
            simulatedQuickAction.perform(from: tabBarController)
        }
        #endif
        UserEngagement.onAppOpen()

        if storeMigrationFailed {
            presentIncompatibleDataAlert()
        }
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let quickAction = QuickAction(rawValue: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        quickAction.perform(from: tabBarController)
        completionHandler(true)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        openCsvImport(url: url)
        return true
    }

    func openCsvImport(url: URL) {
        UserEngagement.logEvent(.openCsvInApp)
        tabBarController.selectedTab = .settings

        let settingsSplitView = tabBarController.selectedSplitViewController!
        let navController = settingsSplitView.masterNavigationController
        navController.dismiss(animated: false)

        // FUTURE: The pop was preventing the segue from occurring. We can end up with a taller
        // than usual navigation stack. Looking for a way to pop and then push in quick succession.
        navController.viewControllers.first!.performSegue(withIdentifier: "settingsData", sender: url)
    }

    @objc func initialiseTheme() {
        let theme = UserDefaults.standard[.theme]
        theme.configureForms()
        window!.tintColor = theme.tint
    }
}
