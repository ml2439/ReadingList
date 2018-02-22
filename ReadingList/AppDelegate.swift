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

        #if DEBUG
        DebugSettings.initialiseFromCommandLine()
        #endif

        // Initialise the persistent store on a background thread. The main thread will return and the LaunchScreen
        // storyboard will remain in place until this is completed, at which point the Main storyboard will be instantiated.
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            PersistentStoreManager.initalisePersistentStore {
                self.window!.rootViewController = Storyboard.Main.instantiateRoot()
            }
        }

        return true
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
    
    func performQuickAction(_ action: QuickAction) {
        func presentFromToRead(_ viewController: UIViewController) {
            // Select the To Read tab
            tabBarController.selectTab(.toRead)
            
            // Dismiss any modal views
            let navController = tabBarController.selectedSplitViewController!.masterNavigationController
            navController.dismiss(animated: false)
            navController.popToRootViewController(animated: false)
            navController.viewControllers[0].present(viewController, animated: true, completion: nil)
        }
        
        if action == .scanBarcode {
            UserEngagement.logEvent(.scanBarcodeQuickAction)
            presentFromToRead(Storyboard.ScanBarcode.rootAsFormSheet())
        }
        else if action == .searchOnline {
            UserEngagement.logEvent(.searchOnlineQuickAction)
            presentFromToRead(Storyboard.SearchOnline.rootAsFormSheet())
        }
    }
}

enum QuickAction: String {
    case scanBarcode = "com.andrewbennet.books.ScanBarcode"
    case searchOnline = "com.andrewbennet.books.SearchBooks"
}
