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
        UserEngagement.initialiseUserAnalytics()

        setupSvProgressHud()
        completeStoreTransactions()

        // Grab any options which we take action on after the persistent store is initialised
        let quickAction = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem
        let csvFileUrl = launchOptions?[.url] as? URL

        initialisePersistentStore {
            // Once the store is loaded and the main storyboard instantiated, perform the quick action
            // or open the CSV file, is specified. This is done here rather than in application:open,
            // for example, in the case where the app is not yet launched.
            if let quickAction = quickAction {
                self.performQuickAction(QuickAction(rawValue: quickAction.type)!)
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
                        DebugSettings.initialiseFromCommandLine()
                        #endif
                        self.window!.rootViewController = TabBarController()

                        // Initialise app-level theme, and monitor the set theme
                        self.initialiseTheme()
                        self.monitorThemeSetting()
                        UserSettings.mostRecentWorkingVersion.value = BuildInfo.appConfiguration.userFacingDescription

                        onSuccess?()
                    }
                }
            } catch MigrationError.incompatibleStore {
                DispatchQueue.main.async {
                    self.storeMigrationFailed = true
                    self.presentIncompatibleDataAlert()
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    func presentIncompatibleDataAlert() {
        guard let mostRecentWorkingVersion = UserSettings.mostRecentWorkingVersion.value else { fatalError("No recorded previously working version") }

        #if RELEASE
        // This is a common error during development, but shouldn't occur in production
        guard mostRecentWorkingVersion != BuildInfo.appConfiguration.userFacingDescription else { fatalError("Migration error thrown for store of same version.") }
        #endif

        guard window!.rootViewController!.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Incompatible Data", message: """
            The data on this device is not compatible with this version of Reading List.

            You previously had version \(mostRecentWorkingVersion), but now have version \(BuildInfo.appConfiguration.userFacingDescription). \
            You will need to install \(mostRecentWorkingVersion) again to be able to access your data.
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

    func setupSvProgressHud() {
        // Prepare the progress display style. Switched to dark in 1.4 due to a bug in the display of light style
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.setDefaultAnimationType(.native)
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.setMinimumDismissTimeInterval(2)
    }

    func completeStoreTransactions() {
        // Apple recommends to register a transaction observer as soon as the app starts.
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            purchases.filter {
                ($0.transaction.transactionState == .purchased || $0.transaction.transactionState == .restored) && $0.needsFinishTransaction
            }.forEach {
                SwiftyStoreKit.finishTransaction($0.transaction)
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
            if DebugSettings.quickActionSimulation == .barcodeScan {
                performQuickAction(.scanBarcode)
            } else if DebugSettings.quickActionSimulation == .searchOnline {
                performQuickAction(.searchOnline)
            }
        #endif
        UserEngagement.onAppOpen()

        if storeMigrationFailed {
            presentIncompatibleDataAlert()
        }
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        performQuickAction(QuickAction(rawValue: shortcutItem.type)!)
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

    func performQuickAction(_ action: QuickAction) {
        func presentFromToRead(_ viewController: UIViewController) {
            // All quick actions are presented from the To Read tab
            tabBarController.selectedTab = .toRead

            // Dismiss any modal views before presenting
            let navController = tabBarController.selectedSplitViewController!.masterNavigationController
            navController.dismissAndPopToRoot()
            navController.viewControllers.first!.present(viewController, animated: true, completion: nil)
        }

        switch action {
        case .scanBarcode:
            UserEngagement.logEvent(.scanBarcodeQuickAction)
            presentFromToRead(UIStoryboard.ScanBarcode.rootAsFormSheet())
        case .searchOnline:
            UserEngagement.logEvent(.searchOnlineQuickAction)
            presentFromToRead(UIStoryboard.SearchOnline.rootAsFormSheet())
        }
    }

    func monitorThemeSetting() {
        NotificationCenter.default.addObserver(self, selector: #selector(initialiseTheme), name: .ThemeSettingChanged, object: nil)
    }

    @objc func initialiseTheme() {
        UserSettings.theme.value.configureForms()
    }
}

enum QuickAction: String {
    case scanBarcode = "com.andrewbennet.books.ScanBarcode"
    case searchOnline = "com.andrewbennet.books.SearchBooks"
}
