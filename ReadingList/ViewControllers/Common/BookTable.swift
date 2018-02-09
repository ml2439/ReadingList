import UIKit
import DZNEmptyDataSet
import CoreData
import CoreSpotlight

class BookTableViewCell: UITableViewCell, ConfigurableCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorsLabel: UILabel!
    @IBOutlet weak var bookCover: UIImageView!
    @IBOutlet weak var readTimeLabel: UILabel?
    
    typealias ResultType = Book
    
    func configureFrom(_ book: Book) {        
        titleLabel.text = book.title
        authorsLabel.text = book.authorsFirstLast
        bookCover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        if book.readState == .reading {
            readTimeLabel?.text = book.startedReading!.toPrettyString()
        }
        else if book.readState == .finished {
            readTimeLabel?.text = book.finishedReading!.toPrettyString()
        }
        else {
            readTimeLabel?.text = nil
        }
        
        #if DEBUG
            if DebugSettings.showSortNumber {
                titleLabel.text =  "(" + (book.sort?.stringValue ?? "none") + ") " + book.title
            }
        #endif
    }
}

class BookTableUpdater: TableUpdater<Book, BookTableViewCell> {
    
    let onChange: (() -> ())?
    
    init(table: UITableView, controller: NSFetchedResultsController<Book>, onChange: (() -> ())? = nil) {
        self.onChange = onChange
        super.init(table: table, controller: controller)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange object: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)  {
        super.controller(controller, didChange: object, at: indexPath, for: type, newIndexPath: newIndexPath)
        
        onChange?()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        super.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
        
        onChange?()
    }
}

class BookTable: AutoUpdatingTableViewController {

    var resultsController: NSFetchedResultsController<Book>!
    var resultsFilterer: FetchedResultsFilterer<Book, BookPredicateBuilder>!
    var readStates: [BookReadState]!
    var searchController: UISearchController!
    
    // Should be overriden by subclasses
    var navigationItemTitle: String { get { return "" } }
    
    var parentSplitViewController: SplitViewController {
        get { return splitViewController as! SplitViewController }
    }

    @IBOutlet weak var tableFooter: UILabel!
    
    override func viewDidLoad() {
    
        /// The UISearchController to which this UITableViewController will be connected.
        configureSearchController()
        
        // Handle the data fetch, sort and filtering
        buildResultsController()
        
        // We will manage the clearing of selections ourselves.
        clearsSelectionOnViewWillAppear = false
        
        // Some search bar styles are slightly different on iOS 11
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        }
        else {
            searchController.searchBar.backgroundColor = tableView.backgroundColor!
            tableView.tableHeaderView = searchController.searchBar
            tableView.setContentOffset(CGPoint(x: 0, y: searchController.searchBar.frame.height), animated: false)
        }
        
        // Set the nav bar title
        navigationItem.title = navigationItemTitle
        
        // Set the table footer text
        tableFooter.text = footerText()
        
        // Set the DZN data set source
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self

        // Watch for changes in book sort order
        NotificationCenter.default.addObserver(self, selector: #selector(bookSortChanged), name: NSNotification.Name.onBookSortOrderChanged, object: nil)
        
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            navigationController!.navigationBar.prefersLargeTitles = UserSettings.useLargeTitles.value
        }
        super.viewWillAppear(animated)
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
        buildResultsController()
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isEditing else { return }
        navigationItem.rightBarButtonItem!.isEnabled = true
        navigationItem.title = "\(tableView.indexPathsForSelectedRows!.count) Selected"
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
                        book.transistionToReading(log: false)
                    }
                    else {
                        book.transistionToFinished(log: false)
                    }
                }
                self.setEditing(false, animated: true)
                UserEngagement.logEvent(.bulkEditReadState)
                UserEngagement.onReviewTrigger()
            })
        }
        
        optionsAlert.addAction(UIAlertAction(title: "Delete\(selectedRows.count > 1 ? " All" : "")", style: .destructive) { [unowned self] _ in
            // Are you sure?
            let confirmDeleteAlert = UIAlertController(title: "Confirm deletion of \(selectedRows.count) book\(selectedRows.count == 1 ? "" : "s")", message: nil, preferredStyle: .actionSheet)
            if let popPresenter = confirmDeleteAlert.popoverPresentationController {
                popPresenter.barButtonItem = sender
            }
            confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [unowned self] _ in
                // Collect the books up-front, since the selected row indexes will change as we modify them
                for book in selectedRows.map(self.resultsController.object) {
                    book.delete(log: false)
                }
                self.setEditing(false, animated: true)
                UserEngagement.logEvent(.bulkDeleteBook)
                UserEngagement.onReviewTrigger()
            })
            self.present(confirmDeleteAlert, animated: true)
        })
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // For iPad, set the popover presentation controller's source
        if let popPresenter = optionsAlert.popoverPresentationController {
            popPresenter.barButtonItem = sender
        }
        
        self.present(optionsAlert, animated: true, completion: nil)
    }
    
    func footerText() -> String? {
        // Override to configure table footer label text
        return nil
    }
    
    func sectionIndex(forReadState readState: BookReadState) -> Int? {
        if let sectionIndex = resultsController.sections?.index(where: {$0.name == String.init(describing: readState.rawValue)}) {
            return resultsController.sections!.startIndex.distance(to: sectionIndex)
        }
        return nil
    }
    
    func readStateForSection(_ section: Int) -> BookReadState {
        return readStates.first{sectionIndex(forReadState: $0) == section}!
    }
    
    func buildResultsController() {
        let readStatePredicate = NSPredicate.Or(readStates.map{BookPredicate.readState(equalTo: $0)})
        resultsController = appDelegate.booksStore.fetchedResultsController(readStatePredicate, initialSortDescriptors: UserSettings.selectedSortOrder)
        tableUpdater = BookTableUpdater(table: tableView, controller: resultsController){ [unowned self] in
            self.tableFooter.text = self.footerText()
        }
        
        let predicateBuilder = BookPredicateBuilder(readStatePredicate: readStatePredicate)
        resultsFilterer = FetchedResultsFilterer(uiSearchController: searchController, tableView: self.tableView, fetchedResultsController: resultsController, predicateBuilder: predicateBuilder){ [unowned self] in
            self.tableFooter.text = self.footerText()
        }
    }
    
    func configureSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.returnKeyType = .done
        searchController.searchBar.placeholder = "Your Library"
        searchController.searchBar.searchBarStyle = .default
        tableView.keyboardDismissMode = .onDrag
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Deselect selected rows, so they don't stay highlighted, but only when in non-split mode
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow, !parentSplitViewController.detailIsPresented {
            self.tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        
        // Work around a stupid bug (https://stackoverflow.com/q/46239530/5513562)
        if #available(iOS 11.0, *), searchController.searchBar.frame.height == 0 {
            navigationItem.searchController?.isActive = false
        }
        
        super.viewDidAppear(animated)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Turn the section name into a BookReadState and use its description property
        let sectionAsInt = Int32(self.resultsController.sections![section].name)!
        return BookReadState(rawValue: sectionAsInt)!.description
    }
    
    /**
     allowTableObscuring determines whether the book details page should actually be shown,
     if showing it will obscure this table
    */
    func simulateBookSelection(_ book: Book, allowTableObscuring: Bool = true) {
        let indexPathOfSelectedBook = self.resultsController.indexPath(forObject: book)
        
        // If there is a row (there might not be is there is a search filtering the results,
        // and clearing the search creates animations which mess up push segues), then
        // scroll to it.
        if let indexPathOfSelectedBook = indexPathOfSelectedBook {
            tableView.scrollToRow(at: indexPathOfSelectedBook, at: .none, animated: true)
        }
        
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
        let navController = segue.destination as? UINavigationController
        
        if let detailsViewController = navController?.topViewController as? BookDetails {
            if let cell = sender as? UITableViewCell,
                let selectedIndex = self.tableView.indexPath(for: cell) {
         
                detailsViewController.book = self.resultsController.object(at: selectedIndex)
            }
            else if let book = sender as? Book {
                detailsViewController.book = book
            }
        }
        else if let editBookController = navController?.viewControllers.first as? EditBook, let book = sender as? Book {
            editBookController.bookToEdit = book
        }
        else if let editReadStateController = navController?.viewControllers.first as? EditReadState, let book = sender as? Book {
            editReadStateController.bookToEdit = book
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
        optionsAlert.addAction(storyboardAction(title: "Enter Manually", storyboard: Storyboard.AddManually))
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // For iPad, set the popover presentation controller's source
        if let popPresenter = optionsAlert.popoverPresentationController {
            popPresenter.barButtonItem = sender
        }
        
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
                self.resultsController.object(at: indexPath).transistionToReading()
            }
            startAction.backgroundColor = UIColor.buttonBlue
            rowActions.append(startAction)
        }
        else if indexPath.section == readingIndex {
            let finishAction = UITableViewRowAction(style: .normal, title: "Finish") { [unowned self] rowAction, indexPath in
                self.resultsController.object(at: indexPath).transistionToFinished()
            }
            finishAction.backgroundColor = UIColor.flatGreen
            rowActions.append(finishAction)
        }
        
        #if DEBUG
            if DebugSettings.showCellReloadControl {
                let reloadCell = UITableViewRowAction(style: .default, title: "Reload") {[unowned self] _, indexPath in
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
                reloadCell.backgroundColor = UIColor.gray
                rowActions.append(reloadCell)
            }
        #endif
        
        return rowActions
    }
    
    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] _,_,callback in
            self.presentDeleteBookAlert(indexPath: indexPath, callback: callback)
        }
        deleteAction.image = #imageLiteral(resourceName: "Trash")
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [unowned self] _,_,callback in
            self.performSegue(withIdentifier: "editBook", sender: self.resultsController.object(at: indexPath))
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
            self.performSegue(withIdentifier: "editReadState", sender: self.resultsController.object(at: indexPath))
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
        if let popPresenter = confirmDeleteAlert.popoverPresentationController {
            let cell = self.tableView.cellForRow(at: indexPath)!
            popPresenter.sourceRect = cell.frame
            popPresenter.sourceView = self.tableView
            popPresenter.permittedArrowDirections = .any
        }
        
        confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            callback?(false)
        })
        confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            bookToDelete.delete()
            callback?(true)
        })
        self.present(confirmDeleteAlert, animated: true, completion: nil)
    }
}

/// DZNEmptyDataSetSource functions
extension BookTable : DZNEmptyDataSetSource {
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let titleText: String!
        if resultsFilterer.showingSearchResults {
            titleText = "🔍 No Results"
        }
        else if readStates.contains(.reading) {
            titleText = "📚 To Read"
        }
        else {
            titleText = "🎉 Finished"
        }
        
        return NSAttributedString(string: titleText, attributes: [NSAttributedStringKey.font: UIFont.gillSans(ofSize: 32),
                                                                  NSAttributedStringKey.foregroundColor: UIColor.gray])
    }
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        if resultsFilterer.showingSearchResults {
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
        let bodyFont = UIFont.gillSans(forTextStyle: .title2)
        let boldFont = UIFont.gillSansSemiBold(forTextStyle: .title2)
        
        if resultsFilterer.showingSearchResults {
            return NSAttributedString.createFromMarkdown("Try changing your search, or add a new book by tapping the **+** button above.", font: bodyFont, boldFont: boldFont)
        }
        if readStates.contains(.reading) {
            return NSAttributedString.createFromMarkdown("Books you add to your **To Read** list, or mark as currently **Reading** will show up here.\n\nAdd a book by tapping the **+** button above.", font: bodyFont, boldFont: boldFont)
        }
        else {
            return NSAttributedString.createFromMarkdown("Books you mark as **Finished** will show up here.\n\nAdd a book by tapping the **+** button above.", font: bodyFont, boldFont: boldFont)
        }
    }
}

extension BookTable: DZNEmptyDataSetDelegate {
    
    // We want to hide the Edit button when there are no items on the screen; show it when there are items on the screen.
    // We want to hide the Search Bar when there are no items, but not due to a search filtering everything out.

    func emptyDataSetDidAppear(_ scrollView: UIScrollView!) {
        if !resultsFilterer.showingSearchResults {
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
