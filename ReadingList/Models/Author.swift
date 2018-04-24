import Foundation
import CoreData

@objc(Author)
public class Author: NSManagedObject {
    @NSManaged private(set) var lastName: String
    @NSManaged private(set) var firstNames: String?

    var displayFirstLast: String {
        return (firstNames == nil ? "" : "\(firstNames!) ") + lastName
    }

    var displayLastCommaFirst: String {
        return lastName + (firstNames == nil ? "" : ", \(firstNames!)")
    }

    convenience init(context: NSManagedObjectContext, lastName: String, firstNames: String?) {
        self.init(context: context)
        self.lastName = lastName
        self.firstNames = firstNames
    }

    static func authorSort(_ authors: [Author]) -> String {
        return authors.map {
            [$0.lastName, $0.firstNames].compactMap {$0?.sortable}.joined(separator: ".")
        }.joined(separator: "..")
    }

    static func authorDisplay(_ authors: [Author]) -> String {
        return authors.map {$0.displayFirstLast}.joined(separator: ", ")
    }
}
