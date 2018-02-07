import Foundation

class ListPredicate {
    private static let nameFieldName = "name"
    
    static let nameSort = NSSortDescriptor(key: ListPredicate.nameFieldName, ascending: true)
}
