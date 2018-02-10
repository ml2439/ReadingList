import Foundation
import CoreData

/// A 'List' is an ordered set of books
@objc(List)
public class List: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var books: NSOrderedSet
    
    // TODO: Consider removing this
    var booksArray: [Book] {
        get { return books.array.map{($0 as! Book)} }
    }
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.name = name
    }
    
    static func getOrCreate(fromContext context: NSManagedObjectContext, withName name: String) -> List {
        if let existingList = ObjectQuery<List>().filtered(\List.name, .equals, name).fetch(1, fromContext: context).first {
            return existingList
        }
        return List(context: context, name: name)
    }
}
