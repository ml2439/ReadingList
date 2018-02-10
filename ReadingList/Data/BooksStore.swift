import CoreData
import MobileCoreServices

/// Interfaces with the CoreData storage of Book objects
class BooksStore {
    
    private let bookEntityName = "Book"
    private let authorEntityName = "Author"
    private let subjectEntityName = "Subject"
    private let listEntityName = "List"
    
    //private let coreDataStack: CoreDataStack
    private var container: NSPersistentContainer!
    private let coreSpotlightStack: CoreSpotlightStack
    var managedObjectContext: NSManagedObjectContext {
        get {
            return container.viewContext
        }
    }
    
    init(storeType: CoreDataStack.PersistentStoreType) {
        //self.coreDataStack = CoreDataStack(momDirectoryName: "books", persistentStoreType: storeType)
        self.coreSpotlightStack = CoreSpotlightStack(domainIdentifier: productBundleIdentifier)
    }
    
    func initalisePersistentStore(hasJustMigrated: Bool = false) {
        /*let storeUrl = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("books.sqlite")
        
        // Old versions stored the persistent store in the documents directory. Check for existent of a file
        // there and - if present - load the persistent container from that store. This will fail triggering
        // the migration which will relocate the store.
        let oldDocumentsStoreUrl = URL.documents.appendingPathComponent("books.sqlite")

        let sourceStoreUrl: URL
        if !hasJustMigrated && FileManager.default.fileExists(atPath: oldDocumentsStoreUrl.path) {
            print("Store detected at old location")
            sourceStoreUrl = oldDocumentsStoreUrl
        }
        else {
            sourceStoreUrl = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("books.sqlite")
        }

        let storeDescription = NSPersistentStoreDescription(url: sourceStoreUrl)
        storeDescription.shouldMigrateStoreAutomatically = false
        storeDescription.shouldInferMappingModelAutomatically = false
        //container.persistentStoreDescriptions = [storeDescription]

        if !NSPersistentContainer.storeIsLatestVersion(sourceStoreUrl, BooksModelVersion.self) {
            container.migrateStore(from: sourceStoreUrl, to: storeUrl, versions: BooksModelVersion.self, deleteSource: true)
        }
        container.loadPersistentStores{ _, error in
            guard error == nil else { fatalError("Error loading store") }
            print("Persistent store loaded")
        }*/
        container = NSPersistentContainer(name: "books")
        container.loadPersistentStores{ _, error in
            guard error == nil else { fatalError("Error loading store") }
            print("Persistent store loaded")
        }
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
            managedObjectContext: self.managedObjectContext,
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
            managedObjectContext: self.managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
    }
    
    /**
     Gets all lists.
    */
    func getAllLists() -> [List] {
        let fetchRequest = NSFetchRequest<List>(entityName: listEntityName)
        fetchRequest.fetchBatchSize = 100
        fetchRequest.sortDescriptors = [ListPredicate.nameSort]
        return (try? managedObjectContext.fetch(fetchRequest)) ?? []
        // TODO: Need to decide best practice for failing fetches...
    }
    
    func getList(withName name: String) -> List? {
        let fetchRequest = NSFetchRequest<List>(entityName: listEntityName)
        fetchRequest.predicate = NSPredicate(stringFieldName: "name", equalTo: name)
        fetchRequest.fetchLimit = 1
        return (try? managedObjectContext.fetch(fetchRequest))?.first
    }
    
    @discardableResult func getOrCreateList(withName name: String) -> List {
        guard let existingList = getList(withName: name) else { return createList(name: name, type: .customList) }
        return existingList
    }
    
    /**
     Retrieves the specified Book, if it exists.
     */
    func get(bookIdUrl: URL) -> Book? {
        let bookObjectId = managedObjectContext.persistentStoreCoordinator!.managedObjectID(forURIRepresentation: bookIdUrl)!
        return managedObjectContext.object(with: bookObjectId) as? Book
    }
    
    /*
     Gets a Subject with the given name, if it exists. Otherwise, creates a new Subject with the name.
    */
    func getOrCreateSubject(withName name: String) -> Subject {
        let fetchRequest = NSFetchRequest<Subject>(entityName: subjectEntityName)
        fetchRequest.predicate = NSPredicate(stringFieldName: "name", equalTo: name)
        fetchRequest.fetchLimit = 1

        let existingSubject = (try? managedObjectContext.fetch(fetchRequest))?.first
        if let existingSubject = existingSubject {
            return existingSubject
        }
        
        let newSubject = container.createNew(entity: subjectEntityName) as! Subject
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
        let books = try? managedObjectContext.fetch(fetchRequest)
        return books?.first
    }
    
    /**
     Gets all of the books in the store
    */
    func getAllBooksAsync(callback: @escaping (([Book]) -> Void), onFail: @escaping ((Error) -> Void)) {
        do {
            let fetchRequest = self.bookFetchRequest()
            fetchRequest.sortDescriptors = [BookPredicate.readStateSort, BookPredicate.sortIndexSort, BookPredicate.startedReadingSort, BookPredicate.finishedReadingSort]
            try managedObjectContext.execute(NSAsynchronousFetchRequest(fetchRequest: fetchRequest) {
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
            return try managedObjectContext.fetch(fetchRequest)
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
            return try managedObjectContext.fetch(fetchRequest)
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
            let books = try managedObjectContext.fetch(fetchRequest)
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
        book.authors.forEach{deleteObject($0 as! NSManagedObject)}
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
        let book = container.createNew(entity: bookEntityName) as! Book
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
        let author = container.createNew(entity: authorEntityName) as! Author
        author.lastName = lastName
        author.firstNames = firstNames
        return author
    }
    
    @discardableResult func createList(name: String, type: ListType) -> List {
        let list = container.createNew(entity: listEntityName) as! List
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
            try managedObjectContext.save()
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
            for book in try managedObjectContext.fetch(bookFetchRequest()) {
                deleteBook(book)
            }
            for list in try managedObjectContext.fetch(NSFetchRequest<List>(entityName: listEntityName)) {
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
            for list in try managedObjectContext.fetch(NSFetchRequest<List>(entityName: listEntityName)) {
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
