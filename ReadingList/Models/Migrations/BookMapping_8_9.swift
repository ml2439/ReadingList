import Foundation
import CoreData

class BookMapping_8_9: NSEntityMigrationPolicy {

    @objc func authorSort(forAuthors: NSOrderedSet) -> String {
        return forAuthors.map{
            let author = ($0 as! NSManagedObject)
            let lastName = sortable((author.value(forKey: "lastName") as! String))
            let firstNames = sortable(author.value(forKey: "firstNames") as? String)
            return [lastName, firstNames].flatMap{$0}.joined(separator: ".")
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
    
    func sortable(_ str: String?) -> String? {
        guard let str = str else { return nil }
        return str.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale.current)
    }
}
