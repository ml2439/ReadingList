import UIKit
import DZNEmptyDataSet
import CoreData
import ReadingList_Foundation

class BookTable: UITableViewController { //swiftlint:disable:this type_body_length

    var resultsController: CompoundFetchedResultsController<Book>!
    var readStates: [BookReadState]!
    var searchController: UISearchController!
    private lazy var orderedDefaultPredicates = readStates.map {
        (readState: $0, predicate: NSPredicate(format: "%K == %ld", #keyPath(Book.readState), $0.rawValue))
    }

    @IBOutlet private weak var tableFooter: UILabel!

    override func viewDidLoad() {
        searchController = UISearchController(filterPlaceholderText: "Your Library")
        searchController.searchResultsUpdater = self

        tableView.keyboardDismissMode = .onDrag
        tableView.register(UINib(BookTableViewCell.self), forCellReuseIdentifier: String(describing: BookTableViewCell.self))

        clearsSelectionOnViewWillAppear = false
        navigationItem.title = readStates.last!.description

        // Handle the data fetch, sort and filtering
        buildResultsController()

        // Some search bar styles are slightly different on iOS 11
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            tableView.tableHeaderView = TableHeaderSearchBar(searchBar: searchController.searchBar)
            tableView.setContentOffset(CGPoint(x: 0, y: searchController.searchBar.frame.height), animated: false)
        }

        // Set the table footer text
        tableFooter.text = footerText()

        configureNavBarButtons()

        // Set the DZN data set source
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self

        // Watch for changes
        NotificationCenter.default.addObserver(self, selector: #selector(bookSortChanged), name: .BookSortOrderChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refetch), name: .PersistentStoreBatchOperationOccurred, object: nil)

        if #available(iOS 11.0, *) {
            monitorLargeTitleSetting()
        }
        monitorThemeSetting()

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        // Deselect selected rows, so they don't stay highlighted, but only when in non-split mode
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow, !splitViewController!.detailIsPresented {
            self.tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        super.viewDidAppear(animated)
    }

    override func initialise(withTheme theme: Theme) {
        super.initialise(withTheme: theme)
        tableFooter.textColor = theme.subtitleTextColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: tableView)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Turn the section name into a BookReadState and use its description property
        let sectionAsInt = Int16(resultsController.sections![section].name)!
        return BookReadState(rawValue: sectionAsInt)!.description
    }

    func buildResultsController() {
        let controllers = orderedDefaultPredicates.map { readState, predicate -> NSFetchedResultsController<Book> in
            let fetchRequest = NSManagedObject.fetchRequest(Book.self, batch: 25)
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = UserSettings.selectedBookSortDescriptors(forReadState: readState)
            return NSFetchedResultsController<Book>(fetchRequest: fetchRequest, managedObjectContext: PersistentStoreManager.container.viewContext, sectionNameKeyPath: #keyPath(Book.readState), cacheName: nil)
        }

        resultsController = CompoundFetchedResultsController(controllers: controllers)
        try! resultsController.performFetch()
        // FUTURE: This is causing causing a retain cycle, but since we don't expect this view controller
        // to get deallocated anyway, it doesn't matter too much.
        resultsController.delegate = self
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        // The search bar should be disabled if editing: searches will clear selections in edit mode,
        // so it's probably better to just prevent searches from occuring.
        searchController.searchBar.isActive = !editing

        // If we have stopped editing, reset the navigation title
        if !isEditing {
            navigationItem.title = readStates.last!.description
        }

        configureNavBarButtons()
    }

    func configureNavBarButtons() {
        let leftButton, rightButton: UIBarButtonItem
        if isEditing {
            // If we're editing, the right button should become an "edit action" button, but be disabled until any books are selected
            leftButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(toggleEditingAnimated))
            rightButton = UIBarButtonItem(image: #imageLiteral(resourceName: "MoreFilledIcon"), style: .plain, target: self, action: #selector(editActionButtonPressed(_:)))
            rightButton.isEnabled = false
        } else {
            // If we're not editing, the right button should revert back to being an Add button
            leftButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(toggleEditingAnimated))
            rightButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addWasPressed(_:)))
        }

        // The edit state may be updated after the emptydataset is shown; the left button should be hidden when empty
        leftButton.setHidden(tableView.isEmptyDataSetVisible)

        navigationItem.leftBarButtonItem = leftButton
        navigationItem.rightBarButtonItem = rightButton
    }

    @objc func bookSortChanged() {
        DispatchQueue.main.async { // I should've commented why this is async; I don't remember why
            self.buildResultsController()
            self.tableView.reloadData()
        }
    }

    @objc func refetch() {
        // FUTURE: This can leave the EmptyDataSet off-screen if a bulk delete has occurred. Can't find a way to prevent this.
        try! self.resultsController.performFetch()
        self.tableFooter.text = self.footerText()
        self.tableView.reloadData()
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
        cell.initialise(withTheme: UserSettings.theme.value)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            guard let selectedRows = tableView.indexPathsForSelectedRows else { return }
            navigationItem.rightBarButtonItem!.isEnabled = true
            navigationItem.title = "\(selectedRows.count) Selected"
        } else {
            guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
            performSegue(withIdentifier: "showDetail", sender: selectedCell)
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection: Int) {
        if let headerTitle = view as? UITableViewHeaderFooterView {
            headerTitle.textLabel?.textColor = .lightGray
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard isEditing else { return }
        // If this deselection was deselecting the only selected row, disable the edit action button and reset the title
        if let selectedRows = tableView.indexPathForSelectedRow, !selectedRows.isEmpty {
            navigationItem.title = "\(selectedRows.count) Selected"
        } else {
            navigationItem.rightBarButtonItem!.isEnabled = false
            navigationItem.title = readStates.last!.description
        }
    }

    @objc func editActionButtonPressed(_ sender: UIBarButtonItem) {
        guard let selectedRows = tableView.indexPathsForSelectedRows, !selectedRows.isEmpty else { return }
        let selectedSectionIndices = selectedRows.map { $0.section }.distinct()
        let selectedReadStates = sectionIndexByReadState.filter { selectedSectionIndices.contains($0.value) }.keys

        let optionsAlert = UIAlertController(title: "Edit \(selectedRows.count) book\(selectedRows.count == 1 ? "" : "s")", message: nil, preferredStyle: .actionSheet)
        optionsAlert.addAction(UIAlertAction(title: "Add to List", style: .default) { _ in
            let books = selectedRows.map(self.resultsController.object)

            self.present(AddToList.getAppropriateVcForAddingBooksToList(books) {
                self.setEditing(false, animated: true)
                UserEngagement.logEvent(.bulkAddBookToList)
                UserEngagement.onReviewTrigger()
            }, animated: true)
        })

        if let readState = selectedReadStates.first, readState != .finished, selectedReadStates.count == 1 {
            let title = (readState == .toRead ? "Start" : "Finish") + (selectedRows.count > 1 ? " All" : "")
            optionsAlert.addAction(UIAlertAction(title: title, style: .default) { _ in
                for book in selectedRows.map(self.resultsController.object) {
                    if readState == .toRead {
                        book.startReading()
                    } else if book.startedReading! < Date() {
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

        optionsAlert.addAction(UIAlertAction(title: "Delete\(selectedRows.count > 1 ? " All" : "")", style: .destructive) { _ in
            let confirm = self.confirmDeleteAlert(indexPaths: selectedRows)
            confirm.popoverPresentationController?.barButtonItem = sender
            self.present(confirm, animated: true)
        })
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        optionsAlert.popoverPresentationController?.barButtonItem = sender

        self.present(optionsAlert, animated: true, completion: nil)
    }

    func footerText() -> String? {
        return sectionIndexByReadState.map {
            let count = tableView(tableView, numberOfRowsInSection: $0.value)
            return "\($0.key.description): \(count) book\(count == 1 ? "" : "s")"
        }.reversed().joined(separator: "\n")
    }

    var sectionIndexByReadState: [BookReadState: Int] {
        return resultsController.sections!.enumerated().reduce(into: [BookReadState: Int]()) { dict, section in
            let readState = BookReadState(rawValue: Int16(section.element.name)!)!
            dict[readState] = section.offset
        }
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
        if allowTableObscuring || splitViewController!.isSplit {
            if let indexPathOfSelectedBook = indexPathOfSelectedBook {
                tableView.selectRow(at: indexPathOfSelectedBook, animated: true, scrollPosition: .none)
            }

            // If there is a detail view presented, update the book
            if splitViewController!.detailIsPresented {
                (splitViewController!.displayedDetailViewController as? BookDetails)?.book = book
            } else {
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
        } else {
            // When a simulated selection triggers a segue, the sender is the Book
            detailsViewController.book = (sender as! Book)
        }
    }

    @IBAction private func addWasPressed(_ sender: UIBarButtonItem) {

        func storyboardAction(title: String, storyboard: UIStoryboard) -> UIAlertAction {
            return UIAlertAction(title: title, style: .default) { _ in
                self.present(storyboard.rootAsFormSheet(), animated: true, completion: nil)
            }
        }

        let optionsAlert = UIAlertController(title: "Add New Book", message: nil, preferredStyle: .actionSheet)
        optionsAlert.addAction(storyboardAction(title: "Scan Barcode", storyboard: .ScanBarcode))
        optionsAlert.addAction(storyboardAction(title: "Search Online", storyboard: .SearchOnline))
        optionsAlert.addAction(UIAlertAction(title: "Add Manually", style: .default) { _ in
            self.present(EditBookMetadata(bookToCreateReadState: .toRead).inThemedNavController(), animated: true, completion: nil)
        })
        optionsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        optionsAlert.popoverPresentationController?.barButtonItem = sender

        self.present(optionsAlert, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        // Start with the delete action
        var rowActions = [UITableViewRowAction(style: .destructive, title: "Delete") { _, indexPath in
            let confirm = self.confirmDeleteAlert(indexPaths: [indexPath])
            confirm.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
            self.present(confirm, animated: true)
        }]

        // Add the other state change actions where appropriate
        if indexPath.section == sectionIndexByReadState[.toRead] {
            let startAction = UITableViewRowAction(style: .normal, title: "Start", color: .buttonBlue) { _, indexPath in
                self.resultsController.object(at: indexPath).startReading()
                PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
            }
            rowActions.append(startAction)
        } else if indexPath.section == sectionIndexByReadState[.reading] {
            let readingBook = self.resultsController.object(at: indexPath)
            if readingBook.startedReading! < Date() {
                let finishAction = UITableViewRowAction(style: .normal, title: "Finish", color: .flatGreen) { _, _ in
                    readingBook.finishReading()
                    PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
                }
                rowActions.append(finishAction)
            }
        }

        return rowActions
    }

    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, callback in
            let confirm = self.confirmDeleteAlert(indexPaths: [indexPath], callback: callback)
            confirm.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
            self.present(confirm, animated: true, completion: nil)
        }
        deleteAction.image = #imageLiteral(resourceName: "Trash")
        let editAction = UIContextualAction(style: .normal, title: "Edit") { _, _, callback in
            self.present(EditBookMetadata(bookToEditID: self.resultsController.object(at: indexPath).objectID).inThemedNavController(), animated: true)
            callback(true)
        }
        editAction.image = #imageLiteral(resourceName: "Literature")
        return UISwipeActionsConfiguration(performFirstActionWithFullSwipe: false, actions: [deleteAction, editAction])
    }

    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        var actions = [UIContextualAction(style: .normal, title: "Log", image: #imageLiteral(resourceName: "Timetable")) { _, _, callback in
            self.present(EditBookReadState(existingBookID: self.resultsController.object(at: indexPath).objectID).inThemedNavController(), animated: true)
            callback(true)
        }]

        let readStateOfSection = sectionIndexByReadState.first { $0.value == indexPath.section }!.key
        guard readStateOfSection == .toRead || (readStateOfSection == .reading && resultsController.object(at: indexPath).startedReading! < Date()) else {
            // It is not "invalid" to have a book with a started date in the future; but it is invalid
            // to have a finish date before the start date. Therefore, hide the finish action if
            // this would be the case.
            return UISwipeActionsConfiguration(performFirstActionWithFullSwipe: false, actions: actions)
        }

        let leadingSwipeAction = UIContextualAction(style: .normal, title: readStateOfSection == .toRead ? "Start" : "Finish") { _, _, callback in
            let book = self.resultsController.object(at: indexPath)
            if readStateOfSection == .toRead {
                book.startReading()
            } else {
                book.finishReading()
            }
            book.managedObjectContext!.saveAndLogIfErrored()
            UserEngagement.logEvent(.transitionReadState)
            callback(true)
        }
        leadingSwipeAction.backgroundColor = readStateOfSection == .toRead ? .buttonBlue : .flatGreen
        leadingSwipeAction.image = readStateOfSection == .toRead ? #imageLiteral(resourceName: "Play") : #imageLiteral(resourceName: "Complete")
        actions.insert(leadingSwipeAction, at: 0)

        return UISwipeActionsConfiguration(actions: actions)
    }

    func confirmDeleteAlert(indexPaths: [IndexPath], callback: ((Bool) -> Void)? = nil) -> UIAlertController {
        let confirmDeleteAlert = UIAlertController(title: indexPaths.count == 1 ? "Confirm delete" : "Confirm deletion of \(indexPaths.count) books", message: nil, preferredStyle: .actionSheet)
        confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            callback?(false)
        })
        confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            indexPaths.map(self.resultsController.object).forEach { $0.delete() }
            PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
            self.setEditing(false, animated: true)
            UserEngagement.logEvent(indexPaths.count > 1 ? .bulkDeleteBook : .deleteBook)
            callback?(true)
        })
        return confirmDeleteAlert
    }
}

extension BookTable: UISearchResultsUpdating {
    func predicate(forSearchText searchText: String?) -> NSPredicate {
        if let searchText = searchText, !searchText.isEmptyOrWhitespace && searchText.trimming().count >= 2 {
            return NSPredicate.wordsWithinFields(searchText, fieldNames: #keyPath(Book.title), #keyPath(Book.authorSort), "ANY \(#keyPath(Book.subjects)).name")
        }
        return NSPredicate(boolean: true) // If we cannot filter with the search text, we should return all results
    }

    func updateSearchResults(for searchController: UISearchController) {
        let searchTextPredicate = self.predicate(forSearchText: searchController.searchBar.text)

        var anyChangedPredicates = false
        for (index, controller) in resultsController.controllers.enumerated() {
            let thisSectionPredicate = NSPredicate.and([orderedDefaultPredicates[index].predicate, searchTextPredicate])
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

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Disable reorderng when searching, or when the sort order is not custom
        guard !searchController.hasActiveSearchTerms else { return false }
        guard let toReadSectionIndex = sectionIndexByReadState[.toRead] else { return false }
        guard UserSettings.tableSortOrders[.toRead]! == .customOrder else { return false }

        // We can reorder the "ToRead" books if there are more than one
        return indexPath.section == toReadSectionIndex && self.tableView(tableView, numberOfRowsInSection: toReadSectionIndex) > 1
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section == proposedDestinationIndexPath.section {
            return proposedDestinationIndexPath
        } else {
            // FUTURE: To work best in the general case, this should see whether the proposed section is lower or higher
            // than the source section, and use that to set the returned IndexPath's row to either 0 or the maximum (respectively)
            return IndexPath(row: 0, section: sourceIndexPath.section)
        }
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

        // We should only have movement in the ToRead secion. We also ignore moves which have no effect
        guard let toReadSectionIndex = sectionIndexByReadState[.toRead] else { return }
        guard sourceIndexPath.section == toReadSectionIndex && destinationIndexPath.section == toReadSectionIndex else { return }
        guard sourceIndexPath.row != destinationIndexPath.row else { return }

        // Get the range of objects that the move affects
        let topRow = [sourceIndexPath.row, destinationIndexPath.row].min()!
        let bottomRow = [sourceIndexPath.row, destinationIndexPath.row].max()!
        var booksInMovementRange = (topRow...bottomRow).map { IndexPath(row: $0, section: toReadSectionIndex) }.map(resultsController.object)

        // Move the objects array to reflect the desired order
        let wasDownwardsMovement = destinationIndexPath.row == bottomRow
        if wasDownwardsMovement {
            let first = booksInMovementRange.removeFirst()
            booksInMovementRange.append(first)
        } else {
            let last = booksInMovementRange.removeLast()
            booksInMovementRange.insert(last, at: 0)
        }

        // Turn off updates while we manipulate the object context
        resultsController.delegate = nil

        // Update the model sort indexes. The lowest sort number should be the sort of the book immediately
        // above the range, plus 1, or (if the range starts at the top) 0.
        var sortIndex: Int32
        if topRow == 0 {
            sortIndex = 0
        } else {
            let indexPath = IndexPath(row: topRow - 1, section: toReadSectionIndex)
            sortIndex = resultsController.object(at: indexPath).sort!.int32 + 1
        }

        for book in booksInMovementRange {
            book.sort = sortIndex.nsNumber
            sortIndex += 1
        }

        PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
        try! resultsController.performFetch()

        // Enable updates again
        resultsController.delegate = self
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
        if type == .update, let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) {
            guard (cell as! BookTableViewCell).requiresUpdate(anObject as! Book) else { return }
        }
        tableView.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        tableView.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}

extension BookTable: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard !tableView.isEditing else { return nil }
        guard let indexPath = tableView.indexPathForRow(at: location), let cell = tableView.cellForRow(at: indexPath) else {
            return nil
        }

        previewingContext.sourceRect = cell.frame
        let bookDetails = UIStoryboard.BookDetails.instantiateViewController(withIdentifier: "BookDetails") as! BookDetails
        bookDetails.book = resultsController.object(at: indexPath)
        return bookDetails
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
}

extension BookTable: DZNEmptyDataSetSource {

    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        if searchController.hasActiveSearchTerms {
            return StandardEmptyDataset.title(withText: "🔍 No Results")
        } else if readStates.contains(.reading) {
            return StandardEmptyDataset.title(withText: "📚 To Read")
        } else {
            return StandardEmptyDataset.title(withText: "🎉 Finished")
        }
    }

    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        if searchController.hasActiveSearchTerms {
            // Shift the "no search results" view up a bit, so the keyboard doesn't obscure it
            return -(tableView.frame.height - 150) / 4
        }

        // The large titles make the empty data set look weirdly low down. Adjust this,
        // by - fairly randomly - the height of the nav bar
        if #available(iOS 11.0, *), navigationController!.navigationBar.prefersLargeTitles {
            return -navigationController!.navigationBar.frame.height
        } else {
            return 0
        }
    }

    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        if searchController.hasActiveSearchTerms {
            return StandardEmptyDataset.description(withMarkdownText: """
                Try changing your search, or add a new book by tapping the **+** button above.
                """)
        }
        if readStates.contains(.reading) {
            return StandardEmptyDataset.description(withMarkdownText: """
                Books you add to your **To Read** list, or mark as currently **Reading** will show up here.

                Add a book by tapping the **+** button above.
                """)
        } else {
            return StandardEmptyDataset.description(withMarkdownText: """
                Books you mark as **Finished** will show up here.

                Add a book by tapping the **+** button above.
                """)
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
        navigationItem.leftBarButtonItem!.setHidden(true)
    }

    func emptyDataSetDidDisappear(_ scrollView: UIScrollView!) {
        searchController.searchBar.isActiveOrVisible = true
        navigationItem.leftBarButtonItem!.setHidden(false)
    }
}
