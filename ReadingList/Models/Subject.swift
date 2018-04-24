import Foundation
import CoreData

// FUTURE: rename to "tag"?
@objc(Subject)
class Subject: NSManagedObject {
    @NSManaged var name: String
    @NSManaged private(set) var books: Set<Book>

    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.name = name
    }

    static func getOrCreate(inContext context: NSManagedObjectContext, withName name: String) -> Subject {
        let subjectFetchRequest = NSManagedObject.fetchRequest(Subject.self, limit: 1)
        subjectFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Subject.name), name)
        subjectFetchRequest.returnsObjectsAsFaults = false
        if let existingSubject = (try! context.fetch(subjectFetchRequest)).first {
            return existingSubject
        }
        return Subject(context: context, name: name)
    }
}
