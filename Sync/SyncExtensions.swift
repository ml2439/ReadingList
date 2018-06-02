import Foundation
import CoreData

extension NSManagedObjectContext {
    func performMergeChanges(from notification: Notification) {
        perform {
            self.mergeChanges(fromContextDidSave: notification)
        }
    }

    func perform(group: DispatchGroup, block: @escaping () -> Void) {
        group.enter()
        perform {
            block()
            group.leave()
        }
    }
}

extension Notification {
    var updatedObjects: Set<NSManagedObject>? {
        return userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>
    }

    var insertedObjects: Set<NSManagedObject>? {
        return userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>
    }

    var deletedObjects: Set<NSManagedObject>? {
        return userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>
    }
}

extension NSManagedObject {
    func inContext(_ context: NSManagedObjectContext) -> NSManagedObject {
        guard managedObjectContext !== context else { return self }
        return context.object(with: objectID)
    }
}
