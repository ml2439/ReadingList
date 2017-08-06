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
import SVProgressHUD

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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        #if !DEBUG
            Fabric.with([Crashlytics.self])
        #endif
        
        // Prepare the progress display style
        SVProgressHUD.setDefaultAnimationType(.native)
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setMinimumDismissTimeInterval(2)

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        UserEngagement.onAppOpen()
    }
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return userActivityType == CSSearchableItemActionType
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType && userActivity.userInfo?[CSSearchableItemActivityIdentifier] is String {
            tabBarController.restoreUserActivityState(userActivity)
            return true
        }
        return false
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "\(productBundleIdentifier).ScanBarcode" {
            tabBarController.selectTab(.toRead)
            tabBarController.performSegue(withIdentifier: "scanBarcode", sender: self)
        }
        if shortcutItem.type == "\(productBundleIdentifier).SearchBooks" {
            tabBarController.selectTab(.toRead)
            tabBarController.performSegue(withIdentifier: "searchByText", sender: self)
        }
        completionHandler(true)
    }
    
    func appVersionDisplay() -> String {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"],
            let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] {
            return "v\(appVersion) (\(buildVersion))"
        }
        else {
            return "Unknown"
        }
    }
}

