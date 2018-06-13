import Foundation
import CoreData

class BookMapping_11_12: NSEntityMigrationPolicy { //swiftlint:disable:this type_name
    // Migrates Author entities to NSCoding-compliant inline data
    
    @objc func authorsAttribute(forAuthors: NSOrderedSet) -> [NSObject] {
        return []
    }
}
