//
//  BooksStore.swift
//  books
//
//  Created by Andrew Bennet on 29/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import CoreData
import MobileCoreServices

/// Interfaces with the CoreData storage of Book objects
class BooksStore {
    
    private let bookEntityName = "Book"
    private let authorEntityName = "Author"
    private let subjectEntityName = "Subject"
    private let listEntityName = "List"
    
    private let coreDataStack: CoreDataStack
    private let coreSpotlightStack: CoreSpotlightStack
    var managedObjectContext: NSManagedObjectContext {
        get {
            return coreDataStack.managedObjectContext
        }
    }
    
    init(storeType: CoreDataStack.PersistentStoreType) {
        self.coreDataStack = CoreDataStack(momDirectoryName: "books", persistentStoreType: storeType)
        self.coreSpotlightStack = CoreSpotlightStack(domainIdentifier: productBundleIdentifier)
    }
    
    /**
     A NSFetchRequest for the Book entities. Has a batch size of 1000 by default.
    */
    private func bookFetchRequest() -> NSFetchRequest<Book> {
        let fetchRequest = NSFetchRequest<Book>(entityName: bookEntityName)
        fetchRequest.fetchBatchSize = 1000
        return fetchRequest
    }
    
    /**
     Creates a NSFetchedResultsController to retrieve books in the given state.
    */
    func fetchedResultsController(_ initialPredicate: NSPredicate?, initialSortDescriptors: [NSSortDescriptor]?) -> NSFetchedResultsController<Book> {
        let fetchRequest = bookFetchRequest()
        fetchRequest.predicate = initialPredicate
        fetchRequest.sortDescriptors = initialSortDescriptors
        return NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.coreDataStack.managedObjectContext,
            sectionNameKeyPath: BookPredicate.readStateFieldName,
            cacheName: nil)
    }
    
    /**
     Creates a NSFetchedResultsController to retrieve all Lists in order of name.
    */
    func fetchedListsController() -> NSFetchedResultsController<List> {
        let fetchRequest = NSFetchRequest<List>(entityName: listEntityName)
        fetchRequest.fetchBatchSize = 100
        fetchRequest.sortDescriptors = [ListPredicate.nameSort]
        return NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.coreDataStack.managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
    }
    
    /**
     Retrieves the specified Book, if it exists.
     */
    func get(bookIdUrl: URL) -> Book? {
        let bookObjectId = coreDataStack.managedObjectContext.persistentStoreCoordinator!.managedObjectID(forURIRepresentation: bookIdUrl)!
        return coreDataStack.managedObjectContext.object(with: bookObjectId) as? Book
    }
    
    /*
     Gets a Subject with the given name, if it exists. Otherwise, creates a new Subject with the name.
    */
    func getOrCreateSubject(withName name: String) -> Subject {
        let fetchRequest = NSFetchRequest<Subject>(entityName: subjectEntityName)
        fetchRequest.predicate = NSPredicate(stringFieldName: "name", equalTo: name)
        fetchRequest.fetchLimit = 1

        let existingSubject = (try? coreDataStack.managedObjectContext.fetch(fetchRequest))?.first
        if let existingSubject = existingSubject {
            return existingSubject
        }
        
        let newSubject = coreDataStack.createNew(entity: subjectEntityName) as! Subject
        newSubject.name = name
        return newSubject
    }
    
    /**
     Returns the first found book with matching GoogleBooks ID or ISBN
    */
    func getIfExists(googleBooksId: String? = nil, isbn: String? = nil) -> Book? {
        // if both are nil, leave early
        guard googleBooksId != nil || isbn != nil else { return nil }
        
        let fetchRequest = NSFetchRequest<Book>(entityName: self.bookEntityName)
        fetchRequest.fetchLimit = 1
        
        let googleBooksPredicate = googleBooksId == nil ? NSPredicate(boolean: false) : BookPredicate.googleBooksIdEqual(to: googleBooksId!)
        let isbnPredicate = isbn == nil ? NSPredicate(boolean: false) : BookPredicate.isbnEqual(to: isbn!)
        
        fetchRequest.predicate = NSPredicate.Or([googleBooksPredicate, isbnPredicate])
        let books = try? coreDataStack.managedObjectContext.fetch(fetchRequest)
        return books?.first
    }
    
    /**
     Gets all of the books in the store
    */
    func getAllBooksAsync(callback: @escaping (([Book]) -> Void), onFail: @escaping ((Error) -> Void)) {
        do {
            let fetchRequest = self.bookFetchRequest()
            fetchRequest.sortDescriptors = [BookPredicate.readStateSort, BookPredicate.sortIndexSort, BookPredicate.startedReadingSort, BookPredicate.finishedReadingSort]
            try coreDataStack.managedObjectContext.execute(NSAsynchronousFetchRequest(fetchRequest: fetchRequest) {
                callback($0.finalResult ?? [])
            })
        }
        catch {
            print("Error fetching objects asyncronously")
            onFail(error)
        }
    }
    
    /**
     Gets all subjects in the store
    */
    func getAllSubjects() -> [Subject] {
        let fetchRequest = NSFetchRequest<Subject>(entityName: subjectEntityName)
        
        do {
            return try coreDataStack.managedObjectContext.fetch(fetchRequest)
        }
        catch {
            print("Error fetching all subjects")
            return []
        }
    }
    
    /**
     Gets all authors in the store
     */
    func getAllAuthors() -> [Author] {
        let fetchRequest = NSFetchRequest<Author>(entityName: authorEntityName)
        
        do {
            return try coreDataStack.managedObjectContext.fetch(fetchRequest)
        }
        catch {
            print("Error fetching all subjects")
            return []
        }
    }
    
    /**
     Adds or updates the book in the Spotlight index.
    */
    func updateSpotlightIndex(for book: Book) {
        coreSpotlightStack.updateItems([book.toSpotlightItem()])
    }
    
    /**
     Gets the current maximum sort index in the books store
    */
    func maxSort() -> Int? {
        let fetchRequest = NSFetchRequest<Book>(entityName: self.bookEntityName)
        fetchRequest.fetchLimit = 1
        
        fetchRequest.sortDescriptors = [BookPredicate.sortIndexDescendingSort]
        do {
            let books = try coreDataStack.managedObjectContext.fetch(fetchRequest)
            return books.first?.sort as? Int
        }
        catch {
            print("Error determining max sort")
            return nil
        }
    }
    
    /**
     Populates the provided book with all the metadata from the supplied instance
    */
    func populateBook(_ book: Book, withMetadata metadata: BookMetadata) {
        book.title = metadata.title!
        book.isbn13 = metadata.isbn13
        book.googleBooksId = metadata.googleBooksId
        book.pageCount = metadata.pageCount as NSNumber?
        book.publicationDate = metadata.publicationDate
        book.bookDescription = metadata.bookDescription
        book.coverImage = metadata.coverImage
        
        // Brute force - delete and remove all authors, then create them all again
        book.authorsArray.forEach{deleteObject($0)}
        let newAuthors = metadata.authors.map{createAuthor(lastName: $0.lastName, firstNames: $0.firstNames)}
        book.authors = NSOrderedSet(array: newAuthors)
        book.firstAuthorLastName = newAuthors.first?.lastName
        
        book.subjects = NSOrderedSet(array: metadata.subjects.map{getOrCreateSubject(withName: $0)})
    }
    
    /**
     Creates a new Book object, populates with the provided metadata, saves the
     object context, and adds the book to the Spotlight index.
     */
    @discardableResult func create(from metadata: BookMetadata, readingInformation: BookReadingInformation, bookSort: Int? = nil, readingNotes: String? = nil) -> Book {
        let book = coreDataStack.createNew(entity: bookEntityName) as! Book
        book.createdWhen = Date()
        
        populateBook(book, withMetadata: metadata)
        book.populate(from: readingInformation)
        book.notes = readingNotes
        
        updateSort(book: book, requestedSort: bookSort)
        
        save()
        updateSpotlightIndex(for: book)
        return book
    }
    
    func createAuthor(lastName: String, firstNames: String?) -> Author {
        let author = coreDataStack.createNew(entity: authorEntityName) as! Author
        author.lastName = lastName
        author.firstNames = firstNames
        return author
    }
    
    @discardableResult func createList(name: String, type: ListType) -> List {
        let list = coreDataStack.createNew(entity: listEntityName) as! List
        list.name = name
        list.type = type
        return list
    }
    
    /**
        Updates the provided book with the provided metadata and reading information (whichever are provided).
        Saves and reindexes in spotlight.
    */
    func update(book: Book, withMetadata metadata: BookMetadata) {
        populateBook(book, withMetadata: metadata)
        
        save()
        updateSpotlightIndex(for: book)
    }
    
    /**
        Updates the provided book with the provided reading information. Leaves the 'notes' field unchanged.
    */
    func update(book: Book, withReadingInformation readingInformation: BookReadingInformation) {
        update(book: book, withReadingInformation: readingInformation, readingNotes: book.notes)
    }
    
    /**
        Updates the provided book with the provided reading information and the provided notes field.
     */
    func update(book: Book, withReadingInformation readingInformation: BookReadingInformation, readingNotes: String?) {
        book.populate(from: readingInformation)
        book.notes = readingNotes
        updateSort(book: book)
        save()
    }
    
    /**
        Updates the supplied book's sort to an appropriate value, using the requested value if possible, the
        current value - if there is one - or the maximum value otherwise.
    */
    private func updateSort(book: Book, requestedSort: Int? = nil) {
        guard book.readState == .toRead else { book.sort = nil; return }
        
        if let specifiedBookSort = requestedSort {
            book.sort = NSNumber(value: specifiedBookSort)
        }
        else if book.sort == nil {
            let maxSort = self.maxSort() ?? -1
            book.sort = NSNumber(value: maxSort + 1)
        }
    }
    
    /**
     Saves the managedObjectContext and suppresses any errors.
     Is automatically called by the Update and Create functions.
    */
    @discardableResult
    func save() -> Bool {
        // TODO: Find a way to make this method private, if possible
        do {
            try coreDataStack.managedObjectContext.save()
            return true
        }
        catch {
            print("Error saving context: \(error)")
            return false
        }
    }
    
    /**
     Deletes the given book from the managed object context.
     Deindexes from Spotlight if necessary.
     */
    func deleteBook(_ book: Book) {
        coreSpotlightStack.deindexItems(withIdentifiers: [book.objectID.uriRepresentation().absoluteString])
        deleteObject(book)
        save()
    }
    
    /**
     Deletes the object and logs if in debug mode
    */
    func deleteObject(_ object: NSManagedObject) {
        #if DEBUG
            print("Deleted object with ID \(object.objectID)")
        #endif
        managedObjectContext.delete(object)
    }
    
    /**
     Deletes **all** book and list objects from the managed object context.
     Deindexes all books from Spotlight if necessary.
    */
    func deleteAll() {
        do {
            for book in try coreDataStack.managedObjectContext.fetch(bookFetchRequest()) {
                deleteBook(book)
            }
            for list in try coreDataStack.managedObjectContext.fetch(NSFetchRequest<List>(entityName: listEntityName)) {
                deleteObject(list)
            }
            save()
        }
        catch {
            print("Error deleting data: \(error)")
        }
    }
    
    /**
     Deletes all lists
    */
    func deleteAllLists() {
        do {
            for list in try coreDataStack.managedObjectContext.fetch(NSFetchRequest<List>(entityName: listEntityName)) {
                deleteObject(list)
            }
            save()
        }
        catch {
            print("Error deleting lists: \(error)")
        }
    }
    
    /**
     Returns a count of the number of books which exist
    */
    func bookCount() -> Int {
        let fetchRequest = bookFetchRequest()
        return (try? managedObjectContext.count(for: fetchRequest)) ?? -1
    }
    
    /**
     Returns a count of the number of lists which exist
     */
    func listCount() -> Int {
        let fetchRequest = NSFetchRequest<List>(entityName: listEntityName)
        return (try? managedObjectContext.count(for: fetchRequest)) ?? -1
    }
    
}
