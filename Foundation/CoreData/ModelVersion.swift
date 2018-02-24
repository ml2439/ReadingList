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
        get {
            return Self.orderedModelVersions.last!
        }
    }
    
    public var successor: Self? {
        let index = Self.orderedModelVersions.index(of: self)!
        guard index != Self.orderedModelVersions.endIndex else { return nil }
        return Self.orderedModelVersions[index + 1]
    }
    
    public init?(storeURL: URL) {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else { return nil }
        let version = Self.orderedModelVersions.first {
            $0.managedObjectModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard let result = version else { return nil }
        self = result
    }
    
    public func managedObjectModel() -> NSManagedObjectModel {
        guard let momURL = modelBundle.url(forResource: name, withExtension: "mom", subdirectory: modelDirectoryName) else { fatalError("model version \(self) not found") }
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
