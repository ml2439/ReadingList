import Foundation
import CoreData

// FUTURE: rename to "tag"?
@objc(Subject)
class Subject: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var books: Set<Book>
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.name = name
    }
    
    override func willSave() {
        super.willSave()
        if !isDeleted && books.count == 0 {
            print("Orphaned subject \(name) deleted before save")
            managedObjectContext?.delete(self)
        }
    }
    
    static func getOrCreate(inContext context: NSManagedObjectContext, withName name: String) -> Subject {
        let subjectFetchRequest = NSManagedObject.fetchRequest(Subject.self, limit: 1)
        subjectFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Subject.name), name)
        if let existingSubject = (try! context.fetch(subjectFetchRequest)).first {
            return existingSubject
        }
        return Subject(context: context, name: name)
    }
}
