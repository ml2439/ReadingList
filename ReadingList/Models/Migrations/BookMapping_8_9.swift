import Foundation
import CoreData

class BookMapping_8_9: NSEntityMigrationPolicy {

    @objc func authorSort(forAuthors: NSOrderedSet) -> String {
        return forAuthors.map{
            let author = ($0 as! NSManagedObject)
            return "\(author.value(forKey: "lastName")!).\(author.value(forKey: "firstNames") ?? "")"
        }.joined(separator: "..")
    }
    
    @objc func authorDisplay(forAuthors: NSOrderedSet) -> String {
        return forAuthors.map{
            let author = ($0 as! NSManagedObject)
            if let firstName = author.value(forKey: "firstNames") {
                return "\(firstName) \(author.value(forKey: "lastName")!)"
            }
            return author.value(forKey: "lastName") as! String
        }.joined(separator: ", ")
    }
}
