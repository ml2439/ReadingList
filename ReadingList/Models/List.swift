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
}
