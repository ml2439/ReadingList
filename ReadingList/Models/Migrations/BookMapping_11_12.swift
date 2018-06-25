import Foundation
import CoreData

class BookMapping_11_12: NSEntityMigrationPolicy { //swiftlint:disable:this type_name
    // Migrates Author entities to NSCoding-compliant inline data
    @objc func authorsAttribute(forAuthors authors: NSOrderedSet) -> [NSObject] {
        return authors.map {
            let author = $0 as! NSManagedObject
            let firstNames = author.value(forKey: "firstNames") as? String
            let lastName = author.value(forKey: "lastName") as! String
            return Author(lastName: lastName, firstNames: firstNames)
        }
    }

    @objc func manualBookId(forGoogleId googleId: String?) -> String? {
        // Generate a new UUID string for each manual book
        if googleId == nil {
            return UUID().uuidString
        } else {
            return nil
        }
    }
}
