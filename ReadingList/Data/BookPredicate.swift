import Foundation

class BookPredicate {
    
    private static let titleFieldName = "title"
    private static let sortFieldName = "sort"
    private static let firstAuthorLastNameFieldName = "firstAuthorLastName"
    private static let startedReadingFieldName = "startedReading"
    private static let finishedReadingFieldName = "finishedReading"
    
    static let readStateFieldName = "readState"
    
    static func readState(equalTo readState: BookReadState) -> NSPredicate {
        return NSPredicate(intFieldName: readStateFieldName, equalTo: Int(readState.rawValue))
    }
    
    static func search(searchString: String) -> NSPredicate {
        return NSPredicate.wordsWithinFields(searchString, fieldNames: titleFieldName, "ANY authors.firstNames", "ANY authors.lastName", "ANY subjects.name")
    }

    static let titleSort = NSSortDescriptor(key: titleFieldName, ascending: true)
    static let authorSort = NSSortDescriptor(key: firstAuthorLastNameFieldName, ascending: true)
    static let startedReadingSort = NSSortDescriptor(key: startedReadingFieldName, ascending: true)
    static let startedReadingDescendingSort = NSSortDescriptor(key: startedReadingFieldName, ascending: false)
    static let finishedReadingSort = NSSortDescriptor(key: finishedReadingFieldName, ascending: true)
    static let finishedReadingDescendingSort = NSSortDescriptor(key: finishedReadingFieldName, ascending: false)
    static let readStateSort = NSSortDescriptor(key: readStateFieldName, ascending: true)
    static let sortIndexSort = NSSortDescriptor(key: sortFieldName, ascending: true)
    static let sortIndexDescendingSort = NSSortDescriptor(key: sortFieldName, ascending: false)
}
