import Foundation
import CoreData

@objc(Author)
public class Author: NSManagedObject {
    @NSManaged var lastName: String
    @NSManaged var firstNames: String?
    
    var displayFirstLast: String {
        get { return (firstNames == nil ? "" : "\(firstNames!) ") + lastName }
    }
    
    var displayLastCommaFirst: String {
        get { return lastName + (firstNames == nil ? "" : ", \(firstNames!)") }
    }
    
    convenience init(context: NSManagedObjectContext, lastName: String, firstNames: String?) {
        self.init(context: context)
        self.lastName = lastName
        self.firstNames = firstNames
    }
}
