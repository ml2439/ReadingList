import Foundation
import CoreData

public extension NSPersistentContainer {

    /**
     Creates a NSPersistentContainer with a single store description describing the store at the provided URL,
     and with both shouldInferMappingModelAutomatically and shouldMigrateStoreAutomatically set to false.
    */
    convenience init(name: String, manuallyMigratedStoreAt storeURL: URL) {
        self.init(name: name)
        persistentStoreDescriptions = [ {
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
        return persistentStoreDescriptions[0].url!
    }

    /**
     Migrates (if necessary) the store to the latest version of the supplied Version type.
     When migrated, loads the persistent store; when complete calls the callback.
    */
    func migrateAndLoad<Version: ModelVersion>(_ version: Version.Type, completion: @escaping () -> Void) throws {
        try migrateStoreIfRequired(version)
        loadPersistentStores { _, error in
            guard error == nil else { fatalError("Error loading store") }
            completion()
        }
    }

    /**
     Migrates the store to the latest version of the supplied Versions if necessary.
    */
    func migrateStoreIfRequired<Version: ModelVersion>(_ version: Version.Type) throws {
        guard let sourceVersion = try Version(storeURL: storeURL) else {
            print("No current store.")
            return
        }

        let migrationSteps = sourceVersion.migrationSteps(to: Version.latest)
        guard !migrationSteps.isEmpty else { return }
        print("Migrating store \(storeURL.lastPathComponent): \(migrationSteps.count) migration steps detected")

        // For each migration step, migrate to a temporary URL and destroy the previous one (except for the sourceURL)
        var currentMigrationStepURL = storeURL
        for (stepNumber, step) in migrationSteps.enumerated() {
            let temporaryURL = URL.temporary()

            let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
            try! manager.migrateStore(from: currentMigrationStepURL, sourceType: NSSQLiteStoreType, options: nil, with: step.mapping, toDestinationURL: temporaryURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)

            currentMigrationStepURL = temporaryURL
            print("Migration step \(stepNumber + 1) complete")
        }

        // Once all migrations are done, place the current temporary store at the original location
        try! persistentStoreCoordinator.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: currentMigrationStepURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        print("Persistent store replaced")

        // Remove any temporary store files once the migration is complete
        FileManager.default.removeTemporaryFiles()
    }
}
