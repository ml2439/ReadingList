import Foundation
import CoreData

extension NSPersistentContainer {
    
    /**
     Migrates a source store at a specified location to a target version, which is saved to the target location.
     If deleteSource = true, deletes the source stores
    */
    public func migrateStore<Version: ModelVersion>(from sourceURL: URL, to targetURL: URL, versions: Version.Type, deleteSource: Bool) {
        print("Migrating store at \(sourceURL.path)")
        guard let sourceVersion = Version(storeURL: sourceURL as URL) else { fatalError("unknown store version at URL \(sourceURL)") }
        
        var currentURL = sourceURL
        let migrationSteps = sourceVersion.migrationSteps(to: Version.latestModelVersion)
        print("\(migrationSteps.count) migration steps detected")
        
        // For each migration step, migrate to a temporary URL and destroy the previous one (except for the sourceURL)
        for step in migrationSteps {
            let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
            let destinationURL = URL.temporary()
            for mapping in step.mappings {
                try! manager.migrateStore(from: currentURL, sourceType: NSSQLiteStoreType, options: nil, with: mapping, toDestinationURL: destinationURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)
            }
            if currentURL != sourceURL {
                persistentStoreCoordinator.destroyStore(at: currentURL)
            }
            currentURL = destinationURL
            print("Migration step complete")
        }
        
        // Once all migrations are done, place the current temporary store at the target URL
        try! persistentStoreCoordinator.replacePersistentStore(at: targetURL, destinationOptions: nil, withPersistentStoreFrom: currentURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        print("Persistent store replaced")
        
        if currentURL != sourceURL {
            persistentStoreCoordinator.destroyStore(at: currentURL)
        }

        // Delete the original source store if requested
        if deleteSource && targetURL != sourceURL {
            persistentStoreCoordinator.destroyStore(at: sourceURL)
            print("Original store destoyed")
        }
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

