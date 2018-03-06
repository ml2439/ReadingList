import UIKit
import SVProgressHUD
import SwiftyStoreKit

var appDelegate: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var tabBarController: TabBarController {
        return window!.rootViewController as! TabBarController
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        UserEngagement.initialiseUserAnalytics()

        setupSvProgressHud()
        completeStoreTransactions()
        
        // Grab any options which we take action on after the persistent store is initialised
        let quickAction = launchOptions?[UIApplicationLaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem
        let csvFileUrl = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL

        // Initialise the persistent store on a background thread. The main thread will return and the LaunchScreen
        // storyboard will remain in place until this is completed, at which point the Main storyboard will be instantiated.
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            PersistentStoreManager.initalisePersistentStore {
                DispatchQueue.main.async {
                    #if DEBUG
                        DebugSettings.initialiseFromCommandLine()
                    #endif
                    self.window!.rootViewController = Storyboard.Main.instantiateRoot()
                    
                    // Once the store is loaded and the main storyboard instantiated, perform the quick action
                    // or open the CSV file, is specified. This is done here rather than in application:open, for example,
                    // in the case where the app is not yet launched.
                    if let quickAction = quickAction {
                        self.performQuickAction(QuickAction(rawValue: quickAction.type)!)
                    }
                    else if let csvFileUrl = csvFileUrl {
                        self.openCsvImport(url: csvFileUrl)
                    }
                }
            }
        }
        
        // If there was a QuickAction or URL-open, it is handled here, so prevent another handler from being called
        return quickAction == nil && csvFileUrl == nil
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
            purchases.filter{($0.transaction.transactionState == .purchased || $0.transaction.transactionState == .restored) && $0.needsFinishTransaction}.forEach{
                SwiftyStoreKit.finishTransaction($0.transaction)
            }
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
            if DebugSettings.quickActionSimulation == .barcodeScan {
                performQuickAction(.scanBarcode)
            }
            else if DebugSettings.quickActionSimulation == .searchOnline {
                performQuickAction(.searchOnline)
            }
        #endif
        UserEngagement.onAppOpen()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        performQuickAction(QuickAction(rawValue: shortcutItem.type)!)
        completionHandler(true)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        openCsvImport(url: url)
        return true
    }
    
    func openCsvImport(url: URL) {
        UserEngagement.logEvent(.openCsvInApp)
        tabBarController.selectTab(.settings)
        
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
            tabBarController.selectTab(.toRead)
            
            // Dismiss any modal views before presenting
            let navController = tabBarController.selectedSplitViewController!.masterNavigationController
            navController.dismissAndPopToRoot()
            navController.viewControllers.first!.present(viewController, animated: true, completion: nil)
        }
        
        switch action{
        case .scanBarcode:
            UserEngagement.logEvent(.scanBarcodeQuickAction)
            presentFromToRead(Storyboard.ScanBarcode.rootAsFormSheet())
        case .searchOnline:
            UserEngagement.logEvent(.searchOnlineQuickAction)
            presentFromToRead(Storyboard.SearchOnline.rootAsFormSheet())
        }
    }
}

enum QuickAction: String {
    case scanBarcode = "com.andrewbennet.books.ScanBarcode"
    case searchOnline = "com.andrewbennet.books.SearchBooks"
}
