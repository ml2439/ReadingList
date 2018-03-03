import Foundation
import CoreData

class BookMapping_9_10: NSEntityMigrationPolicy {
    
    // Adds an "unknown" author to any book which has no authors. This has been not possible to do for a while,
    // but now it becomes a core data constraint so we need to make sure that it is not present.
    
    //FUNCTION($entityPolicy, "destinationInstancesForSourceInstances:manager", $source.authors, $manager)
    @objc func destinationInstances(forSourceInstances: [NSManagedObject], manager: NSMigrationManager) -> [NSManagedObject] {
        let authors = manager.destinationInstances(forEntityMappingName: "AuthorToAuthor", sourceInstances: forSourceInstances)
        if authors.count > 0 { return authors }
        let newAuthor = NSEntityDescription.insertNewObject(forEntityName: "Author", into: manager.destinationContext)
        newAuthor.setValue("Unknown", forKey: "lastName")
        return [newAuthor]
    }
    
    @objc func authorDisplay(forSource source: String) -> String {
        if source == "" { return "Unknown" }
        return source
    }
    
    @objc func authorSort(forSource source: String) -> String {
        if source == "" { return "unknown" }
        return source
    }
}
