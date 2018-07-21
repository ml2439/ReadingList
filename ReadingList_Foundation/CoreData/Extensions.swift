import Foundation
import CoreData

public extension NSManagedObject {
    func delete() {
        guard let context = managedObjectContext else { fatalError("Attempted to delete a book which was not in a context") }
        context.delete(self)
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
        } catch {
            return false
        }
    }
}

public extension NSManagedObjectContext {

    /**
     With a valid URL representation of a Managed Object ID, returns the managed object.
    */
    func object(withID id: URL) -> NSManagedObject {
        return object(with: persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!)
    }
}

public extension NSPersistentStoreCoordinator {

    /**
     Attempts to destory and then delete the store at the specified URL. If an error occurs, prints the error; does not rethrow.
     */
    func destroyAndDeleteStore(at url: URL) {
        do {
            try destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-shm")))
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-wal")))
        } catch let error { //swiftlint:disable:this untyped_error_in_catch
            print("failed to destroy or delete persistent store at \(url)", error)
        }
    }
}

public extension NSError {
    var descriptiveCode: String {
        switch code {
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
        default: return String(code)
        }
    }

    func getCoreDataSaveErrorDescription() -> String {
        if code == NSValidationMultipleErrorsError {
            guard let errors = userInfo[NSDetailedErrorsKey] as? [NSError] else { return "\"Multiple errors\" error without detail" }
            return errors.compactMap { $0.getCoreDataSaveErrorDescription() }.joined(separator: "; ")
        }

        guard let entityName = (userInfo["NSValidationErrorObject"] as? NSManagedObject)?.entity.name,
            let attributeName = userInfo["NSValidationErrorKey"] as? String else {
                return "Save error with code \(descriptiveCode), domain \(domain): \(localizedDescription)"
        }
        return "Save error for entity \"\(entityName)\", attribute \"\(attributeName)\": \(descriptiveCode)"
    }
}

public extension NSEntityMigrationPolicy {

    func copyValue(oldObject: NSManagedObject, newObject: NSManagedObject, key: String) {
        newObject.setValue(oldObject.value(forKey: key), forKey: key)
    }

    func copyValues(oldObject: NSManagedObject, newObject: NSManagedObject, keys: String...) {
        for key in keys {
            copyValue(oldObject: oldObject, newObject: newObject, key: key)
        }
    }
}

public extension NSFetchedResultsController {
    @objc func withoutUpdates(_ block: () -> Void) {
        let delegate = self.delegate
        self.delegate = nil
        block()
        self.delegate = delegate
    }
}
