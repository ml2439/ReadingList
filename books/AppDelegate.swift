//
//  AppDelegate.swift
//  books
//
//  Created by Andrew Bennet on 09/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit
import CoreSpotlight
import Fabric
import Crashlytics
import Firebase
import SVProgressHUD
import SwiftyStoreKit

#if DEBUG
import SimulatorStatusMagic
#endif

let productBundleIdentifier = "com.andrewbennet.books"

var appDelegate: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    lazy var booksStore = BooksStore(storeType: .sqlite)
    
    var tabBarController: TabBarController {
        return window!.rootViewController as! TabBarController
    }
    
    private static let barcodeScanActionName = "\(productBundleIdentifier).ScanBarcode"
    private static let searchOnlineActionName = "\(productBundleIdentifier).SearchBooks"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        configureAnalytics()
        setupSvProgressHud()
        completeStoreTransactions()
        applyCommandLineArgs()

        return true
    }
    
    func applyCommandLineArgs() {
        #if DEBUG
            if CommandLine.arguments.contains("--UITests_PopulateData") {
                Debug.loadTestData()
            }
            if CommandLine.arguments.contains("--UITests_DeleteLists") {
                booksStore.deleteAllLists()
            }
            if CommandLine.arguments.contains("--UITests_PrettyStatusBar") {
                SDStatusBarManager.sharedInstance().enableOverrides()
            }
            DebugSettings.useFixedBarcodeScanImage = CommandLine.arguments.contains("--UITests_FixedBarcodeScanImage")
        #endif
    }
    
    func configureAnalytics() {
        #if !DEBUG
            if UserSettings.sendAnalytics.value { FirebaseApp.configure() }
            if UserSettings.sendCrashReports.value { Fabric.with([Crashlytics.self]) }
        #endif
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
            for purchase in purchases {
                if purchase.transaction.transactionState == .purchased || purchase.transaction.transactionState == .restored {
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                }
            }
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
            switch DebugSettings.quickActionSimulation {
            case .barcodeScan:
                performQuickAction(shortcutType: AppDelegate.barcodeScanActionName)
            case .searchOnline:
                performQuickAction(shortcutType: AppDelegate.searchOnlineActionName)
            default:
                break
            }
        #endif
        UserEngagement.onAppOpen()
    }
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return userActivityType == CSSearchableItemActionType
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType && userActivity.userInfo?[CSSearchableItemActivityIdentifier] is String {
            UserEngagement.logEvent(.spotlightSearch)
            tabBarController.restoreUserActivityState(userActivity)
            return true
        }
        return false
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        performQuickAction(shortcutType: shortcutItem.type)
        completionHandler(true)
    }
    
    func performQuickAction(shortcutType: String) {
        func presentFromToRead(_ viewController: UIViewController) {
            // Select the To Read tab
            tabBarController.selectTab(.toRead)
            
            // Dismiss any modal views
            let navController = tabBarController.selectedSplitViewController!.masterNavigationController
            navController.dismiss(animated: false)
            navController.popToRootViewController(animated: false)
            navController.viewControllers[0].present(viewController, animated: true, completion: nil)
        }
        
        if shortcutType == AppDelegate.barcodeScanActionName {
            UserEngagement.logEvent(.scanBarcodeQuickAction)
            presentFromToRead(Storyboard.ScanBarcode.rootAsFormSheet())
        }
        else if shortcutType == AppDelegate.searchOnlineActionName {
            UserEngagement.logEvent(.searchOnlineQuickAction)
            presentFromToRead(Storyboard.SearchOnline.rootAsFormSheet())
        }
    }
    
    var appVersion: String {
        get {
            guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return "Unknown" }
            return appVersion
        }
    }
    
    var appBuildNumber: String {
        get {
            guard let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return "Unknown" }
            return buildVersion
        }
    }
}

