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
    
    func isValidForUpdate() -> Bool {
        do {
            try validateForUpdate()
            return true
        }
        catch {
            return false
        }
    }
    
    static func fetchRequest<T: NSManagedObject>(_ type: T.Type, limit: Int? = nil, batch: Int? = nil) -> NSFetchRequest<T> {
        let fetchRequest = T.fetchRequest() as! NSFetchRequest<T>
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
        self.saveIfChanged()
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
    func saveIfChanged() {
        guard hasChanges else { return }
        do {
            try save()
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func performAndSave(block: @escaping () -> ()) {
        perform { [unowned self] in
            block()
            self.saveIfChanged()
        }
    }
    
    func performAndSaveAndWait(block: @escaping (_ context: NSManagedObjectContext) -> ()) {
        performAndWait { [unowned self] in
            block(self)
            self.saveIfChanged()
        }
    }
}
