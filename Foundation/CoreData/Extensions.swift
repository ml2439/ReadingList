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
        catch {
            return false
        }
    }
}

extension NSManagedObjectContext {
    
    func childContext(concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType) -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        childContext.parent = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(mergeChanges(fromContextDidSave:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: childContext)
        
        return childContext
    }
    
    func object(withID id: URL) -> NSManagedObject {
        let objectID = persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!
        return object(with: objectID)
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
        perform {
            block()
            // TODO: weak self?
            self.saveOrRollback()
        }
    }
    
    func performAndSaveAndWait(block: @escaping () -> ()) {
        performAndWait {
            block()
            // TODO: weak self?
            self.saveOrRollback()
        }
    }
}
