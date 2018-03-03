#if DEBUG
import SimulatorStatusMagic
import Foundation

extension DebugSettings {
    public static func loadTestData(completion: (() -> ())? = nil) {
        PersistentStoreManager.deleteAll()
        
        let csvPath = Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!
        BookCSVImporter().startImport(fromFileAt: csvPath) { _ in
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    static func initialiseFromCommandLine() {
        if CommandLine.arguments.contains("--UITests_PopulateData") {
            loadTestData()
        }
        if CommandLine.arguments.contains("--UITests_DeleteLists") {
            // TODO
        }
        if CommandLine.arguments.contains("--UITests_PrettyStatusBar") {
            SDStatusBarManager.sharedInstance().enableOverrides()
        }
        DebugSettings.useFixedBarcodeScanImage = CommandLine.arguments.contains("--UITests_FixedBarcodeScanImage")
    }
}
#endif
