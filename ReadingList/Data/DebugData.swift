#if DEBUG
import SimulatorStatusMagic
import Foundation

extension DebugSettings {
    static func loadTestData(includeImages: Bool = true, completion: (() -> Void)? = nil) {
        PersistentStoreManager.deleteAll()

        let csvPath = Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!
        BookCSVImporter().importBooks(includeImages: includeImages, from: csvPath)
            .catch { _ in fatalError("Error importing test data") }
            .then(on: .main) { _ in
                completion?()
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
