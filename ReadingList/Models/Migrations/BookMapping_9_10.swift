import Foundation
import CoreData

class BookMapping_9_10: NSEntityMigrationPolicy {
    
    //FUNCTION($entityPolicy, "destinationInstancesForSourceInstances:manager", $source.authors, $manager)
    @objc func destinationInstances(forSourceInstances sourceInstances: [NSManagedObject], manager: NSMigrationManager) -> [NSManagedObject] {
        let authors = manager.destinationInstances(forEntityMappingName: "AuthorToAuthor", sourceInstances: sourceInstances)
        if authors.count > 0 { return authors }
        let newAuthor = NSEntityDescription.insertNewObject(forEntityName: "Author", into: manager.destinationContext)
        newAuthor.setValue("Unknown", forKey: "lastName")
        return [newAuthor]
    }
}
