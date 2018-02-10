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
}

extension NSManagedObjectContext {
    func object(withID id: URL) -> NSManagedObject {
        let objectID = persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!
        return object(with: objectID)
    }

    @discardableResult func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        }
        catch {
            print("Error saving context: \(error)")
            rollback()
            return false
        }
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
