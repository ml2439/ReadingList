import CoreData

class PersistentStoreManager {
    
    private(set) static var container: NSPersistentContainer!
    
    private static let storeName = "books"
    private static var storeFileName: String { return "\(storeName).sqlite" }
    
    /**
     Creates the NSPersistentContainer, migrating if necessary.
    */
    static func initalisePersistentStore(completion: @escaping () -> ()) {
        guard container == nil else { fatalError("Attempting to reinitialise the PersistentStoreManager") }
        let storeLocation = URL.applicationSupport.appendingPathComponent(storeFileName)

        // Default location of NSPersistentContainer is in the ApplicationSupport directory;
        // previous versions put the store in the Documents directory. Move it if necessary.
        moveStoreFromLegacyLocationIfNecessary(toNewLocation: storeLocation)

        // TODO: Deindex spotlight results if necessary
        
        // Migrate the store to the latest version if necessary and then initialise
        container = NSPersistentContainer(name: storeName, loadManuallyMigratedStoreAt: storeLocation)
        container.loadMigrated(toLatestOf: BooksModelVersion.self) {
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /**
     If a store exists in the Documents directory, copies it to the Application Support directory and destroys
     the old store.
    */
    private static func moveStoreFromLegacyLocationIfNecessary(toNewLocation newLocation: URL) {
        let legacyStoreLocation = URL.documents.appendingPathComponent(storeFileName)
        if FileManager.default.fileExists(atPath: legacyStoreLocation.path) && !FileManager.default.fileExists(atPath: newLocation.path) {
            print("Store located in Documents directory; migrating to Application Support directory")
            let tempStoreCoordinator = NSPersistentStoreCoordinator()
            try! tempStoreCoordinator.replacePersistentStore(at: newLocation, destinationOptions: nil, withPersistentStoreFrom: legacyStoreLocation, sourceOptions: nil, ofType: NSSQLiteStoreType)
            
            // Delete the old store
            tempStoreCoordinator.destroyAndDeleteStore(at: legacyStoreLocation)
        }
    }
}
