import Foundation
import CoreData
import os.log

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
            os_log("No current store: no migration required", type: .info)
            return
        }

        let migrationSteps = sourceVersion.migrationSteps(to: Version.latest)
        guard !migrationSteps.isEmpty else { return }
        os_log("Migrating store at %{public}s: %d migration steps detected", storeURL.path, migrationSteps.count)

        // For each migration step, migrate to a temporary URL and destroy the previous one (except for the sourceURL)
        var currentMigrationStepURL = storeURL
        for (stepNumber, step) in migrationSteps.enumerated() {
            let temporaryURL = URL.temporary()

            let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
            try! manager.migrateStore(from: currentMigrationStepURL, sourceType: NSSQLiteStoreType, options: nil, with: step.mapping, toDestinationURL: temporaryURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)

            currentMigrationStepURL = temporaryURL
            os_log("Migration step %d complete", stepNumber)
        }

        // Once all migrations are done, place the current temporary store at the original location
        try! persistentStoreCoordinator.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: currentMigrationStepURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        os_log("Migration complete; persistent store replaced")

        // Remove any temporary store files once the migration is complete
        FileManager.default.removeTemporaryFiles()
    }
}
