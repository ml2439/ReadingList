import UIKit
import DZNEmptyDataSet
import CoreData

class BookTable: UITableViewController {

    var resultsController: CompoundFetchedResultsController<Book>!
    var readStates: [BookReadState]!
    var searchController: UISearchController!
    var navigationItemTitle: String!

    @IBOutlet weak var tableFooter: UILabel!
    
    override func viewDidLoad() {
        searchController = UISearchController(filterPlaceholderText: "Your Library")
        searchController.searchResultsUpdater = self
        
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UINib(BookTableViewCell.self), forCellReuseIdentifier: String(describing: BookTableViewCell.self))

        clearsSelectionOnViewWillAppear = false
        navigationItemTitle = readStates.last!.description
        navigationItem.title = navigationItemTitle
        
        // Handle the data fetch, sort and filtering
        buildResultsController()
        
        // Some search bar styles are slightly different on iOS 11
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        }
        else {
            searchController.searchBar.backgroundColor = tableView.backgroundColor!
            tableView.tableHeaderView = searchController.searchBar
            tableView.setContentOffset(CGPoint(x: 0, y: searchController.searchBar.frame.height), animated: false)
        }
        
        // Set the table footer text
        tableFooter.text = footerText()
        
        // Set the DZN data set source
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self

        // Watch for changes in book sort order
        NotificationCenter.default.addObserver(self, selector: #selector(bookSortChanged), name: NSNotification.Name.BookSortOrderChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refetch), name: NSNotification.Name.PersistentStoreBatchOperationOccurred, object: nil)
        
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            navigationController!.navigationBar.prefersLargeTitles = UserSettings.useLargeTitles.value
        }
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Deselect selected rows, so they don't stay highlighted, but only when in non-split mode
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow, !(splitViewController as! SplitViewController).detailIsPresented {
            self.tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        super.viewDidAppear(animated)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Turn the section name into a BookReadState and use its description property
        let sectionAsInt = Int16(resultsController.sections![section].name)!
        return BookReadState(rawValue: sectionAsInt)!.description
    }
    
    lazy var defaultPredicates: [BookReadState: NSPredicate] = {
        return readStates.reduce(into: [BookReadState: NSPredicate]()) {
            $0[$1] = NSPredicate(format: "%K == %ld", #keyPath(Book.readState), $1.rawValue)
        }
    }()
    
    func buildResultsController() {
        let controllers = defaultPredicates.map { (readState, predicate) -> NSFetchedResultsController<Book> in
            let f = NSManagedObject.fetchRequest(Book.self, batch: 25)
            f.predicate = predicate
            f.sortDescriptors = UserSettings.selectedBookSortDescriptors(forReadState: readState)
            return NSFetchedResultsController<Book>(fetchRequest: f, managedObjectContext: PersistentStoreManager.container.viewContext, sectionNameKeyPath: #keyPath(Book.readState), cacheName: nil)
        }
        
        resultsController = CompoundFetchedResultsController(controllers: controllers)
        try! resultsController.performFetch()
        resultsController.delegate = self
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        // The search bar should be disabled if editing: searches will clear selections in edit mode,
        // so it's probably better to just prevent searches from occuring.
        searchController.searchBar.isActive = !editing
        
        let leftButton, rightButton: UIBarButtonItem
        if editing {
            // If we're editing, the right button should become an "edit action" button, but be disabled until any books are selected
            leftButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(editWasPressed(_:)))
            rightButton = UIBarButtonItem(image: #imageLiteral(resourceName: "MoreFilledIcon"), style: .plain, target: self, action: #selector(editActionButtonPressed(_:)))
            rightButton.isEnabled = false
        }
        else {
            // If we're not editing, the right button should revert back to being an Add button, and the title should be reset
            navigationItem.title = navigationItemTitle
            leftButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editWasPressed(_:)))
            rightButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addWasPressed(_:)))
        }
        
        // The edit state may be updated after the emptydataset is shown; the left button should be hidden when empty
        leftButton.toggleHidden(hidden: tableView.isEmptyDataSetVisible)
        
        navigationItem.leftBarButtonItem = leftButton
        navigationItem.rightBarButtonItem = rightButton
    }
    
    @objc func bookSortChanged() {
        DispatchQueue.main.async {
            self.buildResultsController()
            self.tableView.reloadData()
        }
    }
    
    @objc func refetch() {
        try! self.resultsController.performFetch()
        self.tableFooter.text = self.footerText()
        self.tableView.reloadData()
        // FUTURE: This can leave the empty data set off-screen. Can't find a way to prevent this.
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return resultsController.sections!.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections![section].numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookTableViewCell", for: indexPath) as! BookTableViewCell
        let book = resultsController.object(at: indexPath)
        cell.configureFrom(book)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            navigationItem.rightBarButtonItem!.isEnabled = true
            navigationItem.title = "\(tableView.indexPathsForSelectedRows!.count) Selected"
        }
        else {
            performSegue(withIdentifier: "showDetail", sender: tableView.cellForRow(at: indexPath)!)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard isEditing else { return }
        // If this deselection was deselecting the only selected row, disable the edit action button and reset the title
        if tableView.indexPathsForSelectedRows?.isEmpty ?? true {
            navigationItem.rightBarButtonItem!.isEnabled = false
            navigationItem.title = navigationItemTitle
        }
        else {
            navigationItem.title = "\(tableView.indexPathsForSelectedRows!.count) Selected"
        }
    }
    
    @objc func editActionButtonPressed(_ sender: UIBarButtonItem) {
        guard let selectedRows = tableView.indexPathsForSelectedRows, selectedRows.count > 0 else { return }
        let selectedReadStates = selectedRows.map{$0.section}.distinct().map{readStateForSection($0)}
        
        let optionsAlert = UIAlertController(title: "Edit \(selectedRows.count) book\(selectedRows.count == 1 ? "" : "s")", message: nil, preferredStyle: .actionSheet)

        optionsAlert.addAction(UIAlertAction(title: "Add to List", style: .default){ [unowned self] _ in
            let books = selectedRows.map(self.resultsController.object)
            
            self.present(AddToList.getAppropriateVcForAddingBooksToList(books) { [unowned self] in
                self.setEditing(false, animated: true)
                UserEngagement.logEvent(.bulkAddBookToList)
                UserEngagement.onReviewTrigger()
            }, animated: true)
        })
        
        if selectedReadStates.count == 1 && selectedReadStates.first! != .finished {
            let readState = selectedReadStates.first!
            var title = readState == .toRead ? "Start" : "Finish"
            if selectedRows.count > 1 {
                title += " All"
            }
            optionsAlert.addAction(UIAlertAction(title: title, style: .default) { [unowned self] _ in
                for book in selectedRows.map(self.resultsController.object) {
                    if readState == .toRead {
                        book.startReading()
                    }
                    else if book.startedReading! < Date() {
                        // It is not "invalid" to have a book with a started date in the future; but it is invalid
                        // to have a finish date before the start date.
                        book.finishReading()
                    }
                }
                PersistentStoreManager.container.viewContext.saveIfChanged()
                self.setEditing(false, animated: true)
                UserEngagement.logEvent(.bulkEditReadState)
                UserEngagement.onReviewTrigger()
            })
        }
        
        optionsAlert.addAction(UIAlertAction(title: "Delete\(selectedRows.count > 1 ? " All" : "")", style: .destructive) { [unowned self] _ in
            // Are you sure?
            let confirmDeleteAlert = UIAlertController(title: "Confirm deletion of \(selectedRows.count) book\(selectedRows.count == 1 ? "" : "s")", message: nil, preferredStyle: .actionSheet)
            confirmDeleteAlert.popoverPresentationController?.barButtonItem = sender
            confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [unowned self] _ in
                // Collect the books up-front, since the selected row indexes will change as we modify them
                for book in selectedRows.map(self.resultsController.object) {
                    book.delete()
                }
                PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
                self.setEditing(false, animated: true)
                UserEngagement.logEvent(.bulkDeleteBook)
                UserEngagement.onReviewTrigger()
            })
            self.present(confirmDeleteAlert, animated: true)
        })
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        optionsAlert.popoverPresentationController?.barButtonItem = sender
        
        self.present(optionsAlert, animated: true, completion: nil)
    }
    
    func footerText() -> String? { fatalError("footerText() not overriden") }
    
    func sectionIndex(forReadState readState: BookReadState) -> Int? {
        if let sectionIndex = resultsController.sections?.index(where: {$0.name == String.init(describing: readState.rawValue)}) {
            return resultsController.sections!.startIndex.distance(to: sectionIndex)
        }
        return nil
    }
    
    func readStateForSection(_ section: Int) -> BookReadState {
        return readStates.first{sectionIndex(forReadState: $0) == section}!
    }

    func simulateBookSelection(_ bookID: NSManagedObjectID, allowTableObscuring: Bool = true) {
        let book = PersistentStoreManager.container.viewContext.object(with: bookID) as! Book
        let indexPathOfSelectedBook = self.resultsController.indexPath(forObject: book)
        
        // If there is a row (there might not be is there is a search filtering the results,
        // and clearing the search creates animations which mess up push segues), then
        // scroll to it.
        if let indexPathOfSelectedBook = indexPathOfSelectedBook {
            tableView.scrollToRow(at: indexPathOfSelectedBook, at: .none, animated: true)
        }
        
        // allowTableObscuring determines whether the book details page should actually be shown, if showing it will obscure this table
        let parentSplitViewController = splitViewController as! SplitViewController
        if allowTableObscuring || parentSplitViewController.isSplit {
            if let indexPathOfSelectedBook = indexPathOfSelectedBook {
                tableView.selectRow(at: indexPathOfSelectedBook, animated: true, scrollPosition: .none)
            }
            
            // If there is a detail view presented, update the book
            if parentSplitViewController.detailIsPresented {
                (parentSplitViewController.displayedDetailViewController as? BookDetails)?.book =  book
            }
            else {
                // Segue to the details view, with the cell corresponding to the book as the sender.
                performSegue(withIdentifier: "showDetail", sender: book)
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // No clicking on books in edit mode, even if you force-press
        return !tableView.isEditing
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navController = segue.destination as? UINavigationController,
            let detailsViewController = navController.topViewController as? BookDetails else { return }

        if let cell = sender as? UITableViewCell, let selectedIndex = self.tableView.indexPath(for: cell) {
            detailsViewController.book = self.resultsController.object(at: selectedIndex)
        }
        else {
            // When a simulated selection triggers a segue, the sender is the Book
            detailsViewController.book = (sender as! Book)
        }
    }
    
    @objc @IBAction func editWasPressed(_ sender: UIBarButtonItem) {
        setEditing(!isEditing, animated: true)
    }
    
    @IBAction func addWasPressed(_ sender: UIBarButtonItem) {
    
        func storyboardAction(title: String, storyboard: UIStoryboard) -> UIAlertAction {
            return UIAlertAction(title: title, style: .default){[unowned self] _ in
                self.present(storyboard.rootAsFormSheet(), animated: true, completion: nil)
            }
        }
        
        let optionsAlert = UIAlertController(title: "Add New Book", message: nil, preferredStyle: .actionSheet)
        optionsAlert.addAction(storyboardAction(title: "Scan Barcode", storyboard: Storyboard.ScanBarcode))
        optionsAlert.addAction(storyboardAction(title: "Search Online", storyboard: Storyboard.SearchOnline))
        optionsAlert.addAction(UIAlertAction(title: "Add Manually", style: .default){ [unowned self] _ in
            self.present(EditBookMetadata(bookToCreateReadState: .toRead).inNavigationController(), animated: true, completion: nil)
        })
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        optionsAlert.popoverPresentationController?.barButtonItem = sender
        
        self.present(optionsAlert, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let toReadIndex = sectionIndex(forReadState: .toRead)
        let readingIndex = sectionIndex(forReadState: .reading)
        
        // Start with the delete action
        var rowActions = [UITableViewRowAction(style: .destructive, title: "Delete") { [unowned self] _, indexPath in
            self.presentDeleteBookAlert(indexPath: indexPath, callback: nil)
        }]
        
        // Add the other state change actions where appropriate
        if indexPath.section == toReadIndex {
            let startAction = UITableViewRowAction(style: .normal, title: "Start") { [unowned self] rowAction, indexPath in
                self.resultsController.object(at: indexPath).startReading()
                PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
            }
            startAction.backgroundColor = UIColor.buttonBlue
            rowActions.append(startAction)
        }
        else if indexPath.section == readingIndex {
            let readingBook = self.resultsController.object(at: indexPath)
            if readingBook.startedReading! < Date() {
                let finishAction = UITableViewRowAction(style: .normal, title: "Finish") { rowAction, indexPath in
                    readingBook.finishReading()
                    PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
                }
                finishAction.backgroundColor = UIColor.flatGreen
                rowActions.append(finishAction)
            }
        }
        
        return rowActions
    }
    
    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] _,_,callback in
            self.presentDeleteBookAlert(indexPath: indexPath, callback: callback)
        }
        deleteAction.image = #imageLiteral(resourceName: "Trash")
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [unowned self] _,_,callback in
            self.present(EditBookMetadata(bookToEditID: self.resultsController.object(at: indexPath).objectID).inNavigationController(), animated: true)
            callback(true)
        }
        editAction.image = #imageLiteral(resourceName: "Literature")
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editReadStateAction = UIContextualAction(style: .normal, title: "Log") { [unowned self] _,_,callback in
            self.present(EditBookReadState(existingBookID: self.resultsController.object(at: indexPath).objectID).inNavigationController(), animated: true)
            callback(true)
        }
        editReadStateAction.image = #imageLiteral(resourceName: "Timetable")
        let configuration = UISwipeActionsConfiguration(actions: [editReadStateAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    func presentDeleteBookAlert(indexPath: IndexPath, callback: ((Bool) -> ())?) {
        let bookToDelete = self.resultsController.object(at: indexPath)
        let confirmDeleteAlert = UIAlertController(title: "Confirm delete", message: nil, preferredStyle: .actionSheet)
        confirmDeleteAlert.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
        
        confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            callback?(false)
        })
        confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            bookToDelete.deleteAndSave()
            callback?(true)
        })
        self.present(confirmDeleteAlert, animated: true, completion: nil)
    }
}

extension BookTable: UISearchResultsUpdating {
    func predicate(forSearchText searchText: String?) -> NSPredicate {
        if let searchText = searchText, !searchText.isEmptyOrWhitespace && searchText.trimming().count >= 2 {
            return NSPredicate.wordsWithinFields(searchText, fieldNames: #keyPath(Book.title), #keyPath(Book.authorDisplay), "ANY \(#keyPath(Book.subjects)).name")
        }
        return NSPredicate(boolean: true) // If we cannot filter with the search text, we should return all results
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchTextPredicate = self.predicate(forSearchText: searchController.searchBar.text)
        
        var anyChangedPredicates = false
        for (index, controller) in resultsController.controllers.enumerated() {
            let thisSectionPredicate = NSPredicate.And([defaultPredicates[readStates[index]]!, searchTextPredicate])
            if controller.fetchRequest.predicate != thisSectionPredicate {
                controller.fetchRequest.predicate = thisSectionPredicate
                anyChangedPredicates = true
            }
        }
        if anyChangedPredicates {
            try! resultsController.performFetch()
            tableView.reloadData()
            tableFooter.text = footerText()
        }
    }
}

extension BookTable: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.controllerWillChangeContent(controller)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.controllerDidChangeContent(controller)
        
        // The fetched results controller delegate is only done manually (rather than set to the tableView) so we
        // can trigger the footer text to reload also
        tableFooter.text = footerText()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        tableView.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        tableView.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}

extension BookTable: DZNEmptyDataSetSource {
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        if searchController.hasActiveSearchTerms {
            return StandardEmptyDataset.title(withText: "🔍 No Results")
        }
        else if readStates.contains(.reading) {
            return StandardEmptyDataset.title(withText: "📚 To Read")
        }
        else {
            return StandardEmptyDataset.title(withText: "🎉 Finished")
        }
    }
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        if searchController.hasActiveSearchTerms {
            // Shift the "no search results" view up a bit, so the keyboard doesn't obscure it
            return -(tableView.frame.height - 150)/4
        }
        
        // The large titles make the empty data set look weirdly low down. Adjust this,
        // by - fairly randomly - the height of the nav bar
        if #available(iOS 11.0, *), navigationController!.navigationBar.prefersLargeTitles {
            return -navigationController!.navigationBar.frame.height
        }
        else {
            return 0
        }
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        if searchController.hasActiveSearchTerms {
            return StandardEmptyDataset.description(withMarkdownText: "Try changing your search, or add a new book by tapping the **+** button above.")
        }
        if readStates.contains(.reading) {
            return StandardEmptyDataset.description(withMarkdownText: "Books you add to your **To Read** list, or mark as currently **Reading** will show up here.\n\nAdd a book by tapping the **+** button above.")
        }
        else {
            return StandardEmptyDataset.description(withMarkdownText: "Books you mark as **Finished** will show up here.\n\nAdd a book by tapping the **+** button above.")
        }
    }
}

extension BookTable: DZNEmptyDataSetDelegate {
    
    // We want to hide the Edit button when there are no items on the screen; show it when there are items on the screen.
    // We want to hide the Search Bar when there are no items, but not due to a search filtering everything out.

    func emptyDataSetDidAppear(_ scrollView: UIScrollView!) {
        if !searchController.hasActiveSearchTerms {
            // Deactivate the search controller so that clearing a search term cannot hide an active search bar
            if searchController.isActive { searchController.isActive = false }
            searchController.searchBar.isActiveOrVisible = false
        }
        navigationItem.leftBarButtonItem!.toggleHidden(hidden: true)
    }
    
    func emptyDataSetDidDisappear(_ scrollView: UIScrollView!) {
        searchController.searchBar.isActiveOrVisible = true
        navigationItem.leftBarButtonItem!.toggleHidden(hidden: false)
    }
}
