import Foundation

class BookPredicateBuilder : SearchPredicateBuilder {
    init(readStatePredicate: NSPredicate){
        self.readStatePredicate = readStatePredicate
    }
    
    let readStatePredicate: NSPredicate
    
    func buildPredicateFrom(searchText: String?) -> NSPredicate {
        var predicate = readStatePredicate
        if let searchText = searchText,
            !searchText.isEmptyOrWhitespace && searchText.trimming().count >= 2 {
            predicate = readStatePredicate.And(BookPredicate.search(searchString: searchText))
        }
        return predicate
    }
}
