#if DEBUG
import SimulatorStatusMagic
import Foundation
    
extension DebugSettings {
    public static func loadTestData(completion: (() -> ())? = nil) {
        PersistentStoreManager.deleteAll()
        
        print("Loading test data")
        let csvPath = Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!
        BookCSVImporter().startImport(fromFileAt: csvPath) { _ in
            print("Test data loaded")
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    static func initialiseFromCommandLine() {
        DebugSettings.useFixedBarcodeScanImage = CommandLine.arguments.contains("--UITests_FixedBarcodeScanImage")
        if CommandLine.arguments.contains("--UITests_PrettyStatusBar") {
            SDStatusBarManager.sharedInstance().enableOverrides()
        }
        
        // long running setup
        if CommandLine.arguments.contains("--UITests_PopulateData") {
            loadTestData {
                if CommandLine.arguments.contains("--UITests_DeleteLists") {
                    PersistentStoreManager.delete(type: List.self)
                    NotificationCenter.default.post(name: .PersistentStoreBatchOperationOccurred, object: nil)
                }
            }
        }
    }
}
#endif
