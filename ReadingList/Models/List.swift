import Foundation
import CoreData

/// A 'List' is an ordered set of books
@objc(List)
public class List: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var books: NSOrderedSet
    @NSManaged var type: ListType
    
    // TODO: Consider removing this
    var booksArray: [Book] {
        get { return books.array.map{($0 as! Book)} }
    }
}

@objc enum ListType: Int32, CustomStringConvertible {
    case customList = 1
    case series = 2
    
    var description: String {
        switch self {
        case .customList: return "List"
        case .series: return "Series"
        }
    }
}

