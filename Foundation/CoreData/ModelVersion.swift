import Foundation
import CoreData

public protocol ModelVersion: Equatable {
    static var orderedModelVersions: [Self] { get }

    var name: String { get }
    var modelBundle: Bundle { get }
    var modelDirectoryName: String { get }
}

extension ModelVersion {

    public static var latest: Self {
        return Self.orderedModelVersions.last!
    }

    public var successor: Self? {
        let index = Self.orderedModelVersions.index(of: self)!
        guard index != Self.orderedModelVersions.endIndex else { return nil }
        return Self.orderedModelVersions[index + 1]
    }

    public init?(storeURL: URL) {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                                                                          at: storeURL, options: nil) else { return nil }

        #if DEBUG
            // Validation check - if multiple model versions match the store, we are in trouble.
            // Run this check in debug mode only as an optimisation.
            let matchingModels = Self.orderedModelVersions.filter {
                $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
            }
            if matchingModels.count > 1 {
                let modelNames = matchingModels.map {$0.name}.joined(separator: ",")
                fatalError("\(matchingModels.count) model versions matched the current store (\(modelNames)). Cannot guarantee that migrations will be performed correctly")
            }
        #endif

        // Small optimisation: reverse the model versions so the most recent is first; if the store is already
        // at the latest version, only one managed object model will need to be loaded.
        let version = Self.orderedModelVersions.reversed().first {
            $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard let result = version else {
            #if DEBUG
                print("##### INCOMPATIBLE STORE DETECTED #####")
                print("Deleting incompatible store; will initialise new store. This will cause a fatal error on a release build.")
                NSPersistentStoreCoordinator().destroyAndDeleteStore(at: storeURL)
                return nil
            #else
                fatalError("Current store did not match any model version")
            #endif
        }
        self = result
    }

    public func managedObjectModel() -> NSManagedObjectModel {
        guard let momURL = modelBundle.url(forResource: name, withExtension: "mom", subdirectory: modelDirectoryName) else {
            fatalError("model version \(self) not found")
        }
        guard let model = NSManagedObjectModel(contentsOf: momURL) else { fatalError("cannot open model at \(momURL)") }
        return model
    }

    public func mappingModelToSuccessor() -> NSMappingModel? {
        guard let nextVersion = successor else { return nil }
        guard let mapping = NSMappingModel(from: [modelBundle], forSourceModel: managedObjectModel(), destinationModel: nextVersion.managedObjectModel()) else {
            // If there is no mapping model, build an inferred one
            print("Loading inferred mapping used for step \(self.name) to \(nextVersion.name).")
            return try! NSMappingModel.inferredMappingModel(forSourceModel: managedObjectModel(), destinationModel: successor!.managedObjectModel())
        }
        print("Loaded specified mapping model for step \(self.name) to \(nextVersion.name).")
        return mapping
    }

    public func migrationSteps(to version: Self) -> [MigrationStep] {
        guard self != version else { return [] }
        guard let mapping = mappingModelToSuccessor(), let nextVersion = successor else { fatalError("couldn't find mapping models") }
        let step = MigrationStep(source: managedObjectModel(), destination: nextVersion.managedObjectModel(), mapping: mapping)
        return [step] + nextVersion.migrationSteps(to: version)
    }
}

public final class MigrationStep {
    var source: NSManagedObjectModel
    var destination: NSManagedObjectModel
    var mapping: NSMappingModel

    init(source: NSManagedObjectModel, destination: NSManagedObjectModel, mapping: NSMappingModel) {
        self.source = source
        self.destination = destination
        self.mapping = mapping
    }
}
