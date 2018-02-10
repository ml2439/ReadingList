import Foundation
import CoreData

extension NSPersistentContainer {
    
    /**
     Creates a NSPersistentContainer with a single store description describing the store at the provided URL,
     and with both shouldInferMappingModelAutomatically and shouldMigrateStoreAutomatically set to false.
    */
    convenience init(name: String, loadManuallyMigratedStoreAt storeURL: URL) {
        self.init(name: name)
        self.persistentStoreDescriptions = [{
            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldInferMappingModelAutomatically = false
            description.shouldMigrateStoreAutomatically = false
            return description
        }()]
    }
    
    /**
     Returns the URL of the first persistent store.
    */
    var storeURL: URL {
        get {
            return persistentStoreDescriptions[0].url!
        }
    }
    
    /**
     Migrates the store to the latest version of the supplied Versions if necessary.
    */
    public func migrateStoreIfRequired<Version: ModelVersion>(toLatestOf versions: Version.Type) {
        guard let sourceVersion = Version(storeURL: storeURL) else {
            print("No current store.")
            return
        }
        
        let migrationSteps = sourceVersion.migrationSteps(to: Version.latest)
        guard migrationSteps.count > 0 else { return }
        print("Migrating store at \(storeURL.path): \(migrationSteps.count) migration steps detected")
        
        // For each migration step, migrate to a temporary URL and destroy the previous one (except for the sourceURL)
        var currentURL = storeURL
        for step in migrationSteps {
            let destinationURL = URL.temporary()
            
            let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
            try! manager.migrateStore(from: currentURL, sourceType: NSSQLiteStoreType, options: nil, with: step.mapping, toDestinationURL: destinationURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)
            
            // Only destroy the intermediate stores - the ones in the temporary directory
            if currentURL != storeURL {
                persistentStoreCoordinator.destroyStore(at: currentURL)
            }
            
            currentURL = destinationURL
            print("Migration step complete")
        }
        
        // Once all migrations are done, place the current temporary store at the target URL
        try! persistentStoreCoordinator.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: currentURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        print("Persistent store replaced")
    }
    
    // TODO: Remove
    func createNew(entity: String) -> NSManagedObject {
        let newItem = NSEntityDescription.insertNewObject(forEntityName: entity, into: viewContext)
        #if DEBUG
            print("Created new object with ID \(newItem.objectID.uriRepresentation().absoluteString)")
        #endif
        return newItem
    }
}

extension NSPersistentStoreCoordinator {
    
    /**
     Attempts to destory the store at the specified URL. If an error occurs, prints the error; does not rethrow.
     */
    public func destroyStore(at url: URL) {
        do {
            try destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        }
        catch let e {
            print("failed to destroy persistent store at \(url)", e)
        }
    }
}

