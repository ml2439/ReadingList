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
}
