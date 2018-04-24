import Foundation
import CoreData

extension NSPersistentContainer {

    /**
     Creates a NSPersistentContainer with a single in memory store description.
     */
    convenience init(inMemoryStoreWithName name: String) {
        self.init(name: name)
        self.persistentStoreDescriptions = [ {
            let description = NSPersistentStoreDescription()
            description.shouldInferMappingModelAutomatically = false
            description.shouldMigrateStoreAutomatically = false
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false
            return description
        }()]
    }
}
