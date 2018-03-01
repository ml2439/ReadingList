import Foundation
import StoreKit
import Crashlytics
import Firebase

class UserEngagement {
    static let appStartupCountKey = "appStartupCount"
    static let userEngagementCountKey = "userEngagementCount"
    
    static func initialiseUserAnalytics() {
        #if !DEBUG
            if UserSettings.sendAnalytics.value { FirebaseApp.configure() }
            if UserSettings.sendCrashReports.value { Fabric.with([Crashlytics.self]) }
        #endif
    }
    
    static func onReviewTrigger() {
        UserDefaults.standard.incrementCounter(withKey: userEngagementCountKey)
        if #available(iOS 10.3, *), shouldTryRequestReview() {
            SKStoreReviewController.requestReview()
        }
    }
    
    static func onAppOpen() {
        UserDefaults.standard.incrementCounter(withKey: appStartupCountKey)
    }
    
    enum Event: String {
        // Add books
        case searchOnline = "Search_Online"
        case scanBarcode = "Scan_Barcode"
        case searchOnlineMultiple = "Search_Online_Multiple"
        case addManualBook = "Add_Manual_Book"
        
        // Data
        case csvImport = "CSV_Import"
        case csvExport = "CSV_Export"
        case deleteAllData = "Delete_All_Data"

        // Modify books
        case transitionReadState = "Transition_Read_State"
        case bulkEditReadState = "Bulk_Edit_Read_State"
        case deleteBook = "Delete_Book"
        case bulkDeleteBook = "Bulk_Delete_Book"
        case editBook = "Edit_Book"
        case editReadState = "Edit_Read_State"
        
        // Lists
        case createList = "Create_List"
        case addBookToList = "Add_Book_To_List"
        case bulkAddBookToList = "Bulk_Add_Book_To_List"
        case removeBookFromList = "Remove_Book_From_List"
        case reorederList = "Reorder_List"
        case deleteList = "Delete_List"
        
        // Quick actions
        case searchOnlineQuickAction = "Quick_Action_Search_Online"
        case scanBarcodeQuickAction = "Quick_Action_Scan_Barcode"
        
        // Settings changes
        case disableAnalytics = "Disable_Analytics"
        case enableAnalytics = "Enable_Analytics"
        case disableCrashReports = "Disable_Crash_Reports"
        case enableCrashReports = "Enable_Crash_Reports"
        
        // Other
        case viewOnAmazon = "View_On_Amazon"
        case openCsvInApp = "Open_CSV_In_App"
    }
    
    static func logEvent(_ event: Event) {
        guard UserSettings.sendAnalytics.value else { return }
        Analytics.logEvent(event.rawValue, parameters: nil)
    }
    
    private static func shouldTryRequestReview() -> Bool {
        let appStartCountMinRequirement = 3
        let userEngagementModulo = 10
        
        let appStartCount = UserDefaults.standard.getCount(withKey: appStartupCountKey)
        let userEngagementCount = UserDefaults.standard.getCount(withKey: userEngagementCountKey)
        
        return appStartCount >= appStartCountMinRequirement && userEngagementCount % userEngagementModulo == 0
    }
    
    static var appVersion: String {
        get { return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String }
    }
    
    static var appBuildNumber: String {
        get { return Bundle.main.infoDictionary!["CFBundleVersion"] as! String }
    }
}
