import Foundation
import CoreData
import Fabric

extension NSManagedObject {
    func delete() {
        guard let context = managedObjectContext else { fatalError("Attempted to delete a book which was not in a context") }
        context.delete(self)
    }
    
    func deleteAndSave() {
        delete()
        managedObjectContext!.saveAndLogIfErrored()
    }
    
    static func fetchRequest<T: NSManagedObject>(_ type: T.Type, limit: Int? = nil, batch: Int? = nil) -> NSFetchRequest<T> {
        // Apple bug: the following lines do not work when run from a test target
        // let fetchRequest = T.fetchRequest() as! NSFetchRequest<T>
        // let fetchRequest = NSFetchRequest<T>(entityName: type.entity().managedObjectClassName)
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: type))
        if let limit = limit { fetchRequest.fetchLimit = limit }
        if let batch = batch { fetchRequest.fetchBatchSize = batch }
        return fetchRequest
    }
    
    func isValidForUpdate() -> Bool {
        do {
            try self.validateForUpdate()
            return true
        }
        catch {
            return false
        }
    }
}

extension NSManagedObjectContext {
    
    /**
     Tries to save the managed object context and logs an event and raises a fatal error if failure occurs.
    */
    func saveAndLogIfErrored() {
        do {
            try self.save()
        }
        catch let error {
            Fabric.log((error as NSError).getCoreDataSaveErrorDescription())
            fatalError(error.localizedDescription)
        }
    }
    
    /**
     Creates a child managed object context, and adds an observer to the child context's save event in order to trigger a merge and save
    */
    func childContext(concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType, autoMerge: Bool = true) -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        childContext.parent = self
        childContext.automaticallyMergesChangesFromParent = autoMerge
        
        NotificationCenter.default.addObserver(self, selector: #selector(mergeAndSave(fromChildContextDidSave:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: childContext)
        
        return childContext
    }
    
    @objc private func mergeAndSave(fromChildContextDidSave notification: Notification) {
        self.mergeChanges(fromContextDidSave: notification)
        self.saveAndLogIfErrored()
    }
    
    /**
     With a valid URL representation of a Managed Object ID, returns the managed object.
    */
    func object(withID id: URL) -> NSManagedObject {
        return object(with: persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!)
    }
    
    /**
     Saves if changes are present in the context.
    */
    @discardableResult func saveIfChanged() -> Bool {
        guard hasChanges else { return false }
        self.saveAndLogIfErrored()
        return true
    }
    
    func performAndSave(block: @escaping () -> ()) {
        perform { [unowned self] in
            block()
            self.saveAndLogIfErrored()
        }
    }
}

extension NSPersistentStoreCoordinator {
    
    /**
     Attempts to destory and then delete the store at the specified URL. If an error occurs, prints the error; does not rethrow.
     */
    public func destroyAndDeleteStore(at url: URL) {
        do {
            try destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-shm")))
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-wal")))
        }
        catch let e {
            print("failed to destroy or delete persistent store at \(url)", e)
        }
    }
}

extension NSError {
    func descriptiveCode() -> String {
        switch self.code {
        case NSManagedObjectValidationError: return "NSManagedObjectValidationError"
        case NSValidationMissingMandatoryPropertyError: return "NSValidationMissingMandatoryPropertyError"
        case NSValidationRelationshipLacksMinimumCountError: return "NSValidationRelationshipLacksMinimumCountError"
        case NSValidationRelationshipExceedsMaximumCountError: return "NSValidationRelationshipExceedsMaximumCountError"
        case NSValidationRelationshipDeniedDeleteError: return "NSValidationRelationshipDeniedDeleteError"
        case NSValidationNumberTooLargeError: return "NSValidationNumberTooLargeError"
        case NSValidationNumberTooSmallError: return "NSValidationNumberTooSmallError"
        case NSValidationDateTooLateError: return "NSValidationDateTooLateError"
        case NSValidationDateTooSoonError: return "NSValidationDateTooSoonError"
        case NSValidationInvalidDateError: return "NSValidationInvalidDateError"
        case NSValidationStringTooLongError: return "NSValidationStringTooLongError"
        case NSValidationStringTooShortError: return "NSValidationStringTooShortError"
        case NSValidationStringPatternMatchingError: return "NSValidationStringPatternMatchingError"
        default: return String(self.code)
        }
    }
    
    func getCoreDataSaveErrorDescription() -> String {
        if self.code == NSValidationMultipleErrorsError {
            guard let errors = self.userInfo[NSDetailedErrorsKey] as? [NSError] else { return "\"Multiple errors\" error without detail" }
            return errors.compactMap{$0.getCoreDataSaveErrorDescription()}.joined(separator: "; ")
        }
        
        let entityName = (self.userInfo["NSValidationErrorObject"] as? NSManagedObject)?.entity.name ?? "Unknown"
        let attributeName = self.userInfo["NSValidationErrorKey"] as? String ?? "Unknown"
        return "Save error for entity \"\(entityName)\", attribute \"\(attributeName)\": \(self.descriptiveCode())"
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

extension NSFetchedResultsController {
    @objc func withoutUpdates(_ block: () -> ()) {
        let delegate = self.delegate
        self.delegate = nil
        block()
        self.delegate = delegate
    }
}
