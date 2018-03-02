import Foundation
import CoreData

/// A 'List' is an ordered set of books
@objc(List)
public class List: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var books: NSOrderedSet
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.name = name
    }
    
    static func getOrCreate(fromContext context: NSManagedObjectContext, withName name: String) -> List {
        let listFetchRequest = NSManagedObject.fetchRequest(List.self, limit: 1)
        listFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(List.name), name)
        listFetchRequest.returnsObjectsAsFaults = false
        if let existingList = (try! context.fetch(listFetchRequest)).first {
            return existingList
        }
        return List(context: context, name: name)
    }
    
    @NSManaged func addBooks(_ values: NSOrderedSet)
    @NSManaged func removeBooks(_ values: NSSet)
    
    static func names(fromContext context: NSManagedObjectContext) -> [String] {
        let fetchRequest = NSManagedObject.fetchRequest(List.self)
        fetchRequest.sortDescriptors = [NSSortDescriptor(\List.name)]
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).map{$0.name}
    }
}
