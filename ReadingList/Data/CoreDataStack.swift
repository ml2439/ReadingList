import CoreData
import Fabric
import Crashlytics

/**
 Standard CoreData boilerplate code.
 An instance of CoreDataStack can be held by a more specific accessing class.
 Post iOS 10 this could potentially be replaced by NSPersistentContainer
*/
class CoreDataStack {
    
    let managedObjectContext: NSManagedObjectContext
    let storeDescriptor: String
    
    enum PersistentStoreType {
        case sqlite
        case inMemory
    }
    
    /**
     Constructs a CoreDataStack which represents the model contained in the .momd file with the specified
     name, for storage in an .sqlite file with the same name.
    */
    init(momDirectoryName: String, persistentStoreType: PersistentStoreType, persistentStoreName: String? = nil, desiredMomName: String? = nil) {
        
        switch persistentStoreType {
        case .sqlite:
            storeDescriptor = NSSQLiteStoreType
        case .inMemory:
            storeDescriptor = NSInMemoryStoreType
        }
        
        let storeUrl: URL? = {
            switch persistentStoreType {
            case .sqlite:
                return FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first!.appendingPathComponent("\(persistentStoreName ?? momDirectoryName).sqlite")
            case .inMemory:
                return nil
            }
        }()
        
        // Create the MOC
        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        let allMomUrls = Bundle.main.urls(forResourcesWithExtension: "mom", subdirectory: "\(momDirectoryName).momd")!
            .sorted{$0.absoluteString.compare($1.absoluteString) == .orderedAscending}
        
        // Desired mom name will likely only be specified in test cases, to create old MOM stores
        // and then subsequently migrate them.
        let desiredMomUrls: [URL]
        if let desiredMomName = desiredMomName {
            let indexOfDesiredMom = allMomUrls.index{$0.absoluteString.contains(desiredMomName)}!
            desiredMomUrls = allMomUrls.prefix(upTo: indexOfDesiredMom + 1).map{$0}
        }
        else {
            desiredMomUrls = allMomUrls
        }
        
        // Build the ManagedObjectModels from the momd/mom files
        let managedObjectModels = desiredMomUrls.map{NSManagedObjectModel(contentsOf: $0)!}

        // Store URL will be null if using an in-memory store
        if let storeUrl = storeUrl, FileManager.default.fileExists(atPath: storeUrl.path) {
            do {
                try migrateStore(at: storeUrl, moms: managedObjectModels)
            }
            catch {
                #if DEBUG
                print("Error migrating store at \(storeUrl)")
                #else
                Crashlytics.sharedInstance().recordError(error)
                #endif
            }
        }
        else {
            #if DEBUG
            print("No persistent store; migration unnecessary")
            #endif
        }
        
        // Once all necessary migrations are done, create the PersistentStoreCoordinator and add it to the MOC
        managedObjectContext.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModels.last!)
        do {
            try managedObjectContext.persistentStoreCoordinator!.addPersistentStore(ofType: storeDescriptor, configurationName: nil, at: storeUrl, options: nil)
        }
        catch {
            #if DEBUG
            print("Error adding persistent store")
            #else
            Crashlytics.sharedInstance().recordError(error)
            #endif
        }
    }
    
    /*
        Core Data progressive migration code, taken from https://gist.github.com/kean/28439b29532993b620497621a4545789
        Also see http://kean.github.io/post/core-data-progressive-migrations
     */
    
    enum MigrationError: Error {
        case IncompatibleModels
    }
    
    // moms: [mom_v1, mom_v2, ... , mom_vN]
    func migrateStore(at storeURL: URL, moms: [NSManagedObjectModel]) throws {
        let idx = try indexOfCompatibleMom(at: storeURL, moms: moms)
        let remaining = moms.suffix(from: (idx + 1))
        guard remaining.count > 0 else { return }
        _ = try remaining.reduce(moms[idx]) { smom, dmom in
            try migrateStore(at: storeURL, from: smom, to: dmom)
            return dmom
        }
    }
    
    private func indexOfCompatibleMom(at storeURL: URL, moms: [NSManagedObjectModel]) throws -> Int {
        let meta = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL)
        guard let idx = moms.index(where: {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: meta)
        }) else {
            throw MigrationError.IncompatibleModels
        }
        return idx
    }
    
    func migrateStore(at storeURL: URL, from smom: NSManagedObjectModel, to dmom: NSManagedObjectModel) throws {
        #if DEBUG
        print("Performing incremental migration")
        #endif
        
        // Prepare temp directory
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        defer {
            _ = try? FileManager.default.removeItem(at: dir)
        }
        
        // Perform migration
        let mapping = try findMapping(from: smom, to: dmom)
        let destURL = dir.appendingPathComponent(storeURL.lastPathComponent)
        let manager = NSMigrationManager(sourceModel: smom, destinationModel: dmom)
        try autoreleasepool {
            try manager.migrateStore(from: storeURL, sourceType: storeDescriptor, options: nil, with: mapping,
                toDestinationURL: destURL, destinationType: storeDescriptor, destinationOptions: nil)
        }
        
        // Replace source store
        let psc = NSPersistentStoreCoordinator(managedObjectModel: dmom)
        try psc.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: destURL,
            sourceOptions: nil, ofType: storeDescriptor)
    }
    
    func findMapping(from smom: NSManagedObjectModel, to dmom: NSManagedObjectModel) throws -> NSMappingModel {
        if let mapping = NSMappingModel(from: Bundle.allBundles, forSourceModel: smom, destinationModel: dmom) {
            return mapping
        }
        return try NSMappingModel.inferredMappingModel(forSourceModel: smom, destinationModel: dmom)
    }
    
    /// Creates a new item of the specified type with the provided entity name.
    func createNew(entity: String) -> NSManagedObject {
        let newItem = NSEntityDescription.insertNewObject(forEntityName: entity, into: managedObjectContext)
        #if DEBUG
            print("Created new object with ID \(newItem.objectID.uriRepresentation().absoluteString)")
        #endif
        return newItem
    }
}
