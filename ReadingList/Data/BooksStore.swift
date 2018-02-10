import CoreData

class BooksStore {
    
    var container: NSPersistentContainer!
    var managedObjectContext: NSManagedObjectContext {
        get {
            return container.viewContext
        }
    }
    
    let storeFileName = "books.sqlite"
    
    func initalisePersistentStore() {
        let storeLocation = URL.applicationSupport.appendingPathComponent(storeFileName)

        // Default location of NSPersistentContainer is in the ApplicationSupport directory;
        // previous versions put the store in the Documents directory. Move it if necessary.
        moveStoreFromLegacyLocationIfNecessary(toNewLocation: storeLocation)

        // TODO: Deindex spotlight results if necessary
        
        // Initialise the container and migrate the store to the latest version if necessary.
        container = NSPersistentContainer(name: "books", loadManuallyMigratedStoreAt: storeLocation)
        container.migrateStoreIfRequired(toLatestOf: BooksModelVersion.self)
        
        container.loadPersistentStores{ _, error in
            guard error == nil else { fatalError("Error loading store") }
            print("Persistent store loaded")
        }
    }
    
    /**
     If a store exists in the Documents directory, copies it to the Application Support directory and destroys
     the old store.
    */
    func moveStoreFromLegacyLocationIfNecessary(toNewLocation newLocation: URL) {
        let legacyStoreLocation = URL.documents.appendingPathComponent(storeFileName)
        if FileManager.default.fileExists(atPath: legacyStoreLocation.path) && !FileManager.default.fileExists(atPath: newLocation.path) {
            print("Store located in Documents directory; migrating to Application Support directory")
            let tempStoreCoordinator = NSPersistentStoreCoordinator()
            try! tempStoreCoordinator.replacePersistentStore(at: newLocation, destinationOptions: nil, withPersistentStoreFrom: legacyStoreLocation, sourceOptions: nil, ofType: NSSQLiteStoreType)
            
            // Delete the old store
            tempStoreCoordinator.destroyAndDeleteStore(at: legacyStoreLocation)
        }
    }

    /**
     Creates a NSFetchedResultsController to retrieve books in the given state.
    */
    func fetchedResultsController(_ initialPredicate: NSPredicate?, initialSortDescriptors: [NSSortDescriptor]?) -> NSFetchedResultsController<Book> {
        let fetchRequest = ObjectQuery<Book>().fetchRequest()
        fetchRequest.fetchBatchSize = 1000
        fetchRequest.predicate = initialPredicate
        fetchRequest.sortDescriptors = initialSortDescriptors
        return NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.managedObjectContext,
            sectionNameKeyPath: BookPredicate.readStateFieldName,
            cacheName: nil)
    }
    
    /**
     Returns the first found book with matching GoogleBooks ID or ISBN
    */
    func getIfExists(googleBooksId: String? = nil, isbn: String? = nil) -> Book? {
        // if both are nil, leave early
        guard googleBooksId != nil || isbn != nil else { return nil }
        
        var predicates = [NSPredicate]()
        if let googleBooksId = googleBooksId {
            predicates.append(NSPredicate(\Book.googleBooksId, .equals, googleBooksId))
        }
        if let isbn = isbn {
            predicates.append(NSPredicate(\Book.isbn13, .equals, isbn))
        }
        return ObjectQuery<Book>().any(predicates).fetch(1, fromContext: container.viewContext).first
    }
    
    /**
     Gets all of the books in the store
    */
    func getAllBooksAsync(callback: @escaping (([Book]) -> Void), onFail: @escaping ((Error) -> Void)) {
        do {
            let fetchRequest = ObjectQuery<Book>()
                .sorted(\Book.readState).sorted(\Book.sort).sorted(\Book.startedReading).sorted(\Book.finishedReading)
                .fetchRequest()
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
     Gets the current maximum sort index in the books store
    */
    func maxSort() -> Int? {
        return ObjectQuery<Book>().sorted(\Book.sort, ascending: false).fetch(1, fromContext: container.viewContext).first?.sort as? Int
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
        book.authors.forEach{($0 as! NSManagedObject).delete()}
        let newAuthors = metadata.authors.map{Author(context: book.managedObjectContext!, lastName: $0.lastName, firstNames: $0.firstNames)}
        book.authors = NSOrderedSet(array: newAuthors)
        book.subjects = NSOrderedSet(array: metadata.subjects.map{Subject.getOrCreate(inContext: book.managedObjectContext!, withName: $0)})
    }
    
    /**
     Creates a new Book object, populates with the provided metadata, saves the
     object context, and adds the book to the Spotlight index.
     */
    @discardableResult func create(from metadata: BookMetadata, readingInformation: BookReadingInformation, bookSort: Int? = nil, readingNotes: String? = nil) -> Book {
        var book: Book!
        container.viewContext.performAndSaveAndWait {
            book = Book(context: self.container.viewContext)
            book.createdWhen = Date()
            
            self.populateBook(book, withMetadata: metadata)
            book.populate(from: readingInformation)
            book.notes = readingNotes
            
            self.updateSort(book: book, requestedSort: bookSort)
        }
        return book
    }
    
    /**
        Updates the provided book with the provided metadata and reading information (whichever are provided).
        Saves and reindexes in spotlight.
    */
    func update(book: Book, withMetadata metadata: BookMetadata) {
        book.performAndSave {
            self.populateBook(book, withMetadata: metadata)
        }
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
        book.performAndSave {
            book.populate(from: readingInformation)
            book.notes = readingNotes
            self.updateSort(book: book)
        }
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
     Deletes **all** book and list objects from the managed object context.
     Deindexes all books from Spotlight if necessary.
    */
    func deleteAll() {
        do {
            for book in try managedObjectContext.fetch(ObjectQuery<Book>().fetchRequest()) {
                book.delete()
            }
            for list in try managedObjectContext.fetch(ObjectQuery<List>().fetchRequest()) {
                list.delete()
            }
            managedObjectContext.saveOrRollback()
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
            for list in try managedObjectContext.fetch(ObjectQuery<List>().fetchRequest()) {
                list.delete()
            }
            managedObjectContext.saveOrRollback()
        }
        catch {
            print("Error deleting lists: \(error)")
        }
    }
    
}
