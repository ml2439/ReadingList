import Foundation
import CoreData

class BookMapping_6_7: NSEntityMigrationPolicy { //swiftlint:disable:this type_name

    func newAuthor(manager: NSMigrationManager, lastName: String, firstNames: String?) -> NSManagedObject {
        let newAuthor = NSEntityDescription.insertNewObject(forEntityName: "Author", into: manager.destinationContext)
        newAuthor.setValue(lastName, forKey: "lastName")
        newAuthor.setValue(firstNames, forKey: "firstNames")
        return newAuthor
    }

    func extractAuthorComponents(authorListString: String?) -> [(lastName: String, firstNames: String?)] {
        var components = [(lastName: String, firstNames: String?)]()
        guard let authors = authorListString?.components(separatedBy: ","), authors.count > 0 else { return components }

        for authorString in (authors.compactMap {$0.trimming().nilIfWhitespace()}) {
            if let range = authorString.range(of: " ", options: .backwards),
                let lastName = authorString[range.upperBound...].trimming().nilIfWhitespace() {
                components.append((lastName: lastName,
                                   firstNames: authorString[..<range.upperBound].trimming().nilIfWhitespace()))
            } else {
                components.append((lastName: authorString, firstNames: nil))
            }
        }
        return components
    }

    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        let newBook = NSEntityDescription.insertNewObject(forEntityName: "Book", into: manager.destinationContext)

        /*
        @NSManaged var title: String
        @NSManaged var isbn13: String?
        @NSManaged var googleBooksId: String?
        @NSManaged var pageCount: NSNumber?
        @NSManaged var publicationDate: Date?
        @NSManaged var bookDescription: String?
        @NSManaged var coverImage: Data?
        @NSManaged var firstAuthorLastName: String? *** NEW ***
        @NSManaged var readState: BookReadState
        @NSManaged var startedReading: Date?
        @NSManaged var finishedReading: Date?
        @NSManaged var notes: String?
        @NSManaged var currentPage: NSNumber?
        @NSManaged var sort: NSNumber?
        @NSManaged var createdWhen: Date
        @NSManaged var subjects: NSOrderedSet
        @NSManaged var authors: NSOrderedSet *** NEW ***
         */
        copyValues(oldObject: sInstance, newObject: newBook, keys: "title", "isbn13", "googleBooksId", "pageCount", "publicationDate", "bookDescription", "coverImage", "readState", "startedReading", "finishedReading", "notes", "currentPage", "sort", "createdWhen")

        // Copy subjects
        let sourceSubjects = (sInstance.value(forKey: "subjects") as! NSOrderedSet).map {$0 as! NSManagedObject}
        let destinationSubjects = manager.destinationInstances(forEntityMappingName: "SubjectToSubject",
                                                               sourceInstances: sourceSubjects)
        newBook.setValue(NSOrderedSet(array: destinationSubjects), forKey: "subjects")

        // Create authors
        let previousAuthorList = sInstance.value(forKey: "authorList") as! String?
        let newAuthorsComponents = extractAuthorComponents(authorListString: previousAuthorList)
        var newAuthorObjects = [NSManagedObject]()
        for authorComponents in newAuthorsComponents {
            newAuthorObjects.append(newAuthor(manager: manager, lastName: authorComponents.lastName, firstNames: authorComponents.firstNames))
        }
        newBook.setValue(NSOrderedSet(array: newAuthorObjects), forKey: "authors")
        newBook.setValue(newAuthorsComponents.first?.lastName, forKey: "firstAuthorLastName")
    }
}
