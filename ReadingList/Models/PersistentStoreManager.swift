import CoreData
import CoreSpotlight

class PersistentStoreManager {

    private(set) static var container: NSPersistentContainer!

    private static let storeName = "books"
    private static var storeFileName: String { return "\(storeName).sqlite" }

    /**
     Creates the NSPersistentContainer, migrating if necessary.
    */
    static func initalisePersistentStore(completion: @escaping () -> Void) {
        guard container == nil else { fatalError("Attempting to reinitialise the PersistentStoreManager") }
        let storeLocation = URL.applicationSupport.appendingPathComponent(storeFileName)

        // Default location of NSPersistentContainer is in the ApplicationSupport directory;
        // previous versions put the store in the Documents directory. Move it if necessary.
        moveStoreFromLegacyLocationIfNecessary(toNewLocation: storeLocation)

        // Migrate the store to the latest version if necessary and then initialise
        container = NSPersistentContainer(name: storeName, manuallyMigratedStoreAt: storeLocation)
        container.migrateAndLoad(BooksModelVersion.self) {
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            completion()
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

            // The same version (1.7.1) also removed support for spotlight indexing, so deindex everything
            if CSSearchableIndex.isIndexingAvailable() {
                CSSearchableIndex.default().deleteAllSearchableItems()
            }
        }
    }

    /**
     Deletes all objects of the given type
    */
    static func delete<T>(type: T.Type) where T: NSManagedObject {
        print("Deleting all \(String(describing: type)) objects")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: type.fetchRequest())
        try! PersistentStoreManager.container.persistentStoreCoordinator.execute(batchDelete, with: container.viewContext)
    }

    /**
     Deletes all data from the persistent store.
    */
    static func deleteAll() {
        delete(type: List.self)
        delete(type: Subject.self)
        delete(type: Book.self)
        NotificationCenter.default.post(name: Notification.Name.PersistentStoreBatchOperationOccurred, object: nil)
    }
}

extension Notification.Name {
    static let PersistentStoreBatchOperationOccurred = Notification.Name("persistent-store-batch-delete-occurred")
}
