import Foundation
import CoreData

extension NSPersistentContainer {
    
    /**
     Creates a NSPersistentContainer with a single store description describing the store at the provided URL,
     and with both shouldInferMappingModelAutomatically and shouldMigrateStoreAutomatically set to false.
    */
    convenience init(name: String, manuallyMigratedStoreAt storeURL: URL) {
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
     Migrates (if necessary) the store to the latest version of the supplied Version type.
     When migrated, loads the persistent store; when complete calls the callback.
    */
    public func migrateAndLoad<Version: ModelVersion>(_ version: Version.Type, completion: @escaping () -> ()) {
        self.migrateStoreIfRequired(version)
        self.loadPersistentStores { _, error in
            guard error == nil else { fatalError("Error loading store") }
            completion()
        }
    }
    
    /**
     Migrates the store to the latest version of the supplied Versions if necessary.
    */
    public func migrateStoreIfRequired<Version: ModelVersion>(_ version: Version.Type) {
        guard let sourceVersion = Version(storeURL: storeURL) else {
            print("No current store.")
            return
        }
        
        let migrationSteps = sourceVersion.migrationSteps(to: Version.latest)
        guard migrationSteps.count > 0 else { return }
        print("Migrating store \(storeURL.lastPathComponent): \(migrationSteps.count) migration steps detected")
        
        // For each migration step, migrate to a temporary URL and destroy the previous one (except for the sourceURL)
        var currentURL = storeURL
        for step in migrationSteps {
            let destinationURL = URL.temporary()

            let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
            try! manager.migrateStore(from: currentURL, sourceType: NSSQLiteStoreType, options: nil, with: step.mapping, toDestinationURL: destinationURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)
            
            // Only destroy the intermediate stores - the ones in the temporary directory
            if currentURL != storeURL {
                persistentStoreCoordinator.destroyAndDeleteStore(at: currentURL)
            }
            
            currentURL = destinationURL
            print("Migration step complete")
        }
        
        // Once all migrations are done, place the current temporary store at the target URL
        try! persistentStoreCoordinator.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: currentURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        print("Persistent store replaced")
    }
}

extension NSPersistentStoreCoordinator {
    
    /**
     Attempts to destory and then delete the store at the specified URL. If an error occurs, prints the error; does not rethrow.
     */
    public func destroyAndDeleteStore(at url: URL) {
        do {
            try destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-shm")))
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-wal")))
        }
        catch let e {
            print("failed to destroy or delete persistent store at \(url)", e)
        }
    }
}

