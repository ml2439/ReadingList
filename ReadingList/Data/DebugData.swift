#if DEBUG
import SimulatorStatusMagic
import Foundation

extension DebugSettings {
    public static func loadTestData(includeImages: Bool = true, completion: (() -> Void)? = nil) {
        PersistentStoreManager.deleteAll()

        print("Loading test data")
        let csvPath = Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!
        BookCSVImporter(includeImages: includeImages).startImport(fromFileAt: csvPath) { _ in
            print("Test data loaded")
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    static func initialiseFromCommandLine() {
        let screenshots = CommandLine.arguments.contains("--UITests_Screenshots")
        DebugSettings.useFixedBarcodeScanImage = screenshots
        if screenshots {
            SDStatusBarManager.sharedInstance().enableOverrides()
        }

        // long running setup
        if CommandLine.arguments.contains("--UITests_PopulateData") {
            loadTestData(includeImages: screenshots) {
                if CommandLine.arguments.contains("--UITests_DeleteLists") {
                    PersistentStoreManager.delete(type: List.self)
                    NotificationCenter.default.post(name: .PersistentStoreBatchOperationOccurred, object: nil)
                }
            }
        }
    }
}
#endif
