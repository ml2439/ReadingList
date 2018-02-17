import Foundation
import CoreData

extension NSManagedObject {
    func delete() {
        guard let context = managedObjectContext else { fatalError("Attempted to delete a book which was not in a context") }
        context.delete(self)
    }
    
    func deleteAndSave() {
        delete()
        managedObjectContext!.saveOrRollback()
    }
    
    func performAndSave(block: @escaping () -> ()){
        self.managedObjectContext!.performAndSave {
            block()
        }
    }
    
    func isValidForUpdate() -> Bool {
        do {
            try validateForUpdate()
            return true
        }
        catch let error {
            print(error)
            return false
        }
    }
}

extension NSManagedObjectContext {
    
    /**
     Creates a child managed object context, and adds an observer to the child context's save event, triggering notification to
    */
    func childContext(concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType) -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        childContext.parent = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(mergeSave(fromChildContextDidSave:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: childContext)
        
        return childContext
    }
    
    @objc private func mergeSave(fromChildContextDidSave notification: Notification) {
        self.mergeChanges(fromContextDidSave: notification)
        self.saveIfChanged()
    }
    
    /**
     With a valid URL representation of a Managed Object ID, returns the managed object.
    */
    func object(withID id: URL) -> NSManagedObject {
        let objectID = persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!
        return object(with: objectID)
    }
    
    /**
     Saves if changes are present in the context. If an error occurs, prints the error and throws a fatalError.
    */
    func saveIfChanged() {
        guard hasChanges else { return }
        do {
            try save()
        }
        catch {
            print("Error saving context. \(error)")
            fatalError(error.localizedDescription)
        }
    }
    
    /**
     Checks for changes. If changes are present, tries to save. Returns false if the save operation failed.
    */
    func trySaveIfChanged() -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        }
        catch {
            print("Error saving context: \(error)")
            return false
        }
    }

    @discardableResult func saveOrRollback() -> Bool {
        let didSave = trySaveIfChanged()
        if !didSave { rollback() }
        return didSave
    }
    
    func performAndSave(block: @escaping () -> ()) {
        perform { [unowned self] in
            block()
            // TODO: weak self?
            self.saveOrRollback()
        }
    }
    
    func performAndSaveAndWait(block: @escaping () -> ()) {
        performAndWait { [unowned self] in
            block()
            // TODO: weak self?
            self.saveOrRollback()
        }
    }
}
