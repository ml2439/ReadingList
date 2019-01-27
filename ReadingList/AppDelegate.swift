import UIKit
import SVProgressHUD
import SwiftyStoreKit
import CoreData
import ReadingList_Foundation
import os.log
import Reachability

var appDelegate: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var storeMigrationFailed = false
    let reachability = Reachability()!

    /**
     Will be nil until after the persistent store is initialised.
    */
    var syncCoordinator: SyncCoordinator?

    var tabBarController: TabBarController {
        return window!.rootViewController as! TabBarController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        DebugSettings.initialiseSettings()
        #endif

        UserEngagement.initialiseUserAnalytics()
        SVProgressHUD.setDefaults()
        SwiftyStoreKit.completeTransactions()
        UpgradeActionApplier().performUpgrade()

        monitorNetworkReachability()

        // Remote notifications are required for iCloud sync.
        application.registerForRemoteNotifications()

        // Grab any options which we take action on after the persistent store is initialised
        let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem
        let csvFileUrl = launchOptions?[.url] as? URL

        initialisePersistentStore {
            // Once the store is loaded and the main storyboard instantiated, perform the shortcut action
            // or open the CSV file, is specified. This is done here rather than in application:open,
            // for example, in the case where the app is not yet launched.
            if let shortcutItem = shortcutItem {
                self.performShortcut(shortcutItem.type)
            } else if let csvFileUrl = csvFileUrl {
                self.openCsvImport(url: csvFileUrl)
            }
        }

        // If there was a QuickAction or URL-open, it is handled here, so prevent another handler from being called
        return shortcutItem == nil && csvFileUrl == nil
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
                        DebugSettings.initialiseData()
                        #endif

                        self.window!.rootViewController = TabBarController()

                        // Initialise app-level theme, and monitor the set theme
                        self.initialiseTheme()
                        NotificationCenter.default.addObserver(self, selector: #selector(self.initialiseTheme),
                                                               name: .ThemeSettingChanged, object: nil)
                        UserDefaults.standard[.mostRecentWorkingVersion] = BuildInfo.appConfiguration.fullDescription

                        // Initialise the Sync Coordinator which will maintain iCloud synchronisation
                        self.syncCoordinator = SyncCoordinator(container: PersistentStoreManager.container)
                        if UserDefaults.standard[.iCloudSyncEnabled] {
                            self.syncCoordinator!.start()
                        }

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
        if let shortcutType = UserDefaults.standard.string(forKey: "shortcut-type-simulation") {
            performShortcut(shortcutType)
        }
        #endif
        UserEngagement.onAppOpen()

        if storeMigrationFailed {
            presentIncompatibleDataAlert()
        }
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        performShortcut(shortcutItem.type)
        completionHandler(true)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        openCsvImport(url: url)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        os_log("Successfully registered for remote notifications", type: .info)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("Failed to register for remote notifications: %{public}s", type: .error, error.localizedDescription)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if UserDefaults.standard[.iCloudSyncEnabled], let syncCoordinator = syncCoordinator, syncCoordinator.remote.isInitialised {
            syncCoordinator.remoteNotificationReceived(applicationCallback: completionHandler)
        }
    }

    func monitorNetworkReachability() {
        do {
            try reachability.startNotifier()
            NotificationCenter.default.addObserver(self, selector: #selector(networkConnectivityDidChange), name: .reachabilityChanged, object: nil)
        } catch {
            os_log("Error starting reachability notifier: %{public}s", type: .error, error.localizedDescription)
        }
    }

    @objc func networkConnectivityDidChange() {
        guard let syncCoordinator = syncCoordinator else { return }
        let currentConnection = reachability.connection
        os_log("Network connectivity changed to %{public}s", type: .info, currentConnection.description)
        if currentConnection == .none {
            syncCoordinator.stop()
        } else {
            syncCoordinator.start()
        }
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

    func performShortcut(_ type: String) {
        func presentFromToRead(_ viewController: UIViewController) {
            // All quick actions are presented from the To Read tab
            tabBarController.selectedTab = .toRead

            // Dismiss any modal views before presenting
            let navController = tabBarController.selectedSplitViewController!.masterNavigationController
            navController.dismissAndPopToRoot()
            navController.viewControllers.first!.present(viewController, animated: true, completion: nil)
        }

        switch type {
        case ShortcutType.scanBarcode.rawValue:
            UserEngagement.logEvent(.scanBarcodeQuickAction)
            presentFromToRead(UIStoryboard.ScanBarcode.rootAsFormSheet())
        case ShortcutType.searchOnline.rawValue:
            UserEngagement.logEvent(.searchOnlineQuickAction)
            presentFromToRead(UIStoryboard.SearchOnline.rootAsFormSheet())
        default:
            assertionFailure("Unexpected shortcut type: \(type)")
        }
    }

    @objc func initialiseTheme() {
        let theme = UserDefaults.standard[.theme]
        theme.configureForms()
        window!.tintColor = theme.tint
    }
}

enum ShortcutType: String {
    case scanBarcode = "com.andrewbennet.books.ScanBarcode"
    case searchOnline = "com.andrewbennet.books.SearchBooks"
}
