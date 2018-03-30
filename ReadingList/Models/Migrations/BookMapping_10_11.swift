import Foundation
import CoreData

// NOTE:
// Book model version 11 originally was identical to version 10, and introduced in v1.7.4.
// The purpose of the model migration was to recaulcate potentially missing author sort & display
// attributes from v1.7.3. However, since the model version was the same as v10, and it had no version
// hash, _and_ because at the time the model compatibility was checked starting with the earliest
// model, the migration from 10 to 11 would be performed *every* time the app laoded. One fix would be
// to add a version hash to v11. The next time the app loads, any already-migrated stores would migrate
// one more time to v11, and then no longer match v10. What we have done instead, though, is modify
// store v11, to fix an unrelated bug. This has the same effect - existing v11 stores will now report
// as being incompatible with v11, but compatible with v10, and migrate to the "new" v11. At the same
// time we changed the order of the model compatibility check, so it starts with the most recent. This
// is OK provided that, going forward, we remember to always add a version hash for any model versions
// which do not change anything about the store (i.e. exist just for data modification).

class BookMapping_10_11: NSEntityMigrationPolicy {
    // This mapping exists to recalculate any author display / sort values which were missed out in v1.7.3
    
    @objc func authorSort(forAuthors: NSOrderedSet) -> String {
        return forAuthors.map{
            let author = ($0 as! NSManagedObject)
            let lastName = sortable((author.value(forKey: "lastName") as! String))
            let firstNames = sortable(author.value(forKey: "firstNames") as? String)
            return [lastName, firstNames].compactMap{$0}.joined(separator: ".")
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

