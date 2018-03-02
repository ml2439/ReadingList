import Foundation
import CoreData

extension NSManagedObject {
    func delete() {
        guard let context = managedObjectContext else { fatalError("Attempted to delete a book which was not in a context") }
        context.delete(self)
    }
    
    func deleteAndSave() {
        delete()
        try! managedObjectContext!.save()
    }
    
    static func fetchRequest<T: NSManagedObject>(_ type: T.Type, limit: Int? = nil, batch: Int? = nil) -> NSFetchRequest<T> {
        // Apple bug: the following line does not work when run from a test target
        // let fetchRequest = T.fetchRequest() as! NSFetchRequest<T>
        let fetchRequest = NSFetchRequest<T>(entityName: type.entity().managedObjectClassName)
        if let limit = limit { fetchRequest.fetchLimit = limit }
        if let batch = batch { fetchRequest.fetchBatchSize = batch }
        return fetchRequest
    }
}

extension NSManagedObjectContext {
    
    /**
     Creates a child managed object context, and adds an observer to the child context's save event in order to trigger a merge and save
    */
    func childContext(concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType) -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        childContext.parent = self
        childContext.automaticallyMergesChangesFromParent = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(mergeAndSave(fromChildContextDidSave:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: childContext)
        
        return childContext
    }
    
    @objc private func mergeAndSave(fromChildContextDidSave notification: Notification) {
        self.mergeChanges(fromContextDidSave: notification)
        try! self.save()
    }
    
    /**
     With a valid URL representation of a Managed Object ID, returns the managed object.
    */
    func object(withID id: URL) -> NSManagedObject {
        return object(with: persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!)
    }
    
    /**
     Saves if changes are present in the context. If an error occurs, throws a fatalError.
    */
    @discardableResult func saveIfChanged() -> Bool {
        guard hasChanges else { return false }
        do {
            try save()
            return true
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func performAndSave(block: @escaping () -> ()) {
        perform { [unowned self] in
            block()
            try! self.save()
        }
    }
    
    func performAndSaveAndWait(block: @escaping (_ context: NSManagedObjectContext) -> ()) {
        performAndWait { [unowned self] in
            block(self)
            try! self.save()
        }
    }
}

extension NSEntityMigrationPolicy {
    
    func copyValue(oldObject: NSManagedObject, newObject: NSManagedObject, key: String) {
        newObject.setValue(oldObject.value(forKey: key), forKey: key)
    }
    
    func copyValues(oldObject: NSManagedObject, newObject: NSManagedObject, keys: String...) {
        for key in keys {
            copyValue(oldObject: oldObject, newObject: newObject, key: key)
        }
    }

}
