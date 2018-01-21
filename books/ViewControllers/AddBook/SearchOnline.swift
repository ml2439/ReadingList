//
//  SearchOnline.swift
//  books
//
//  Created by Andrew Bennet on 25/08/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit
import SVProgressHUD
import DZNEmptyDataSet
import Crashlytics

class SearchOnline: ArrayBackedTableController<GoogleBooks.SearchResult>, UISearchBarDelegate {
    
    var initialSearchString: String?
    
    @IBOutlet weak var addAllButton: UIBarButtonItem!
    @IBOutlet weak var selectModeButton: UIBarButtonItem!
    
    private var searchController: UISearchController!
    private let feedbackGenerator = UIFeedbackGeneratorWrapper()
    private let emptyDatasetView = NibView.searchBooksEmptyDataset

    override func viewDidLoad() {
        super.viewDidLoad()

        cellIdentifier = "SearchResultCell"
        
        tableView.tableFooterView = UIView()
        tableView.backgroundView = emptyDatasetView

        searchController = NoCancelButtonSearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.text = initialSearchString
        searchController.searchBar.delegate = self

        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        else {
            tableView.tableHeaderView = searchController.searchBar
        }
        
        // If we have an entry-point search, fire it off now
        if let initialSearchString = initialSearchString  {
            performSearch(searchText: initialSearchString)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Deselect any highlighted row (i.e. selected row if not in edit mode)
        if !tableView.isEditing, let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
        
        // Bring up the keyboard if not results, the toolbar if there are some results
        if tableItems.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.searchController.searchBar.becomeFirstResponder()
            }
        }
        else {
            navigationController!.setToolbarHidden(false, animated: true)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        emptyDatasetView.setTopDistance(tableView.universalContentInset.top + 20)
    }

    @IBAction func cancelWasPressed(_ sender: Any) {
        searchController.isActive = false
        dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.isEditing else { return }
        if tableView.indexPathsForSelectedRows == nil || tableView.indexPathsForSelectedRows!.count == 0 {
            addAllButton.isEnabled = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let searchResult = tableItems[indexPath.row]
        
        // Duplicate check
        if let existingBook = appDelegate.booksStore.getIfExists(googleBooksId: searchResult.id, isbn: searchResult.isbn13) {
            presentDuplicateBookAlert(book: existingBook, fromSelectedIndex: indexPath); return
        }
        
        // If we are in multiple selection mode (i.e. Edit mode), switch the Add All button on; otherwise, fetch and segue
        if tableView.isEditing {
           addAllButton.isEnabled = true
        }
        else {
            fetchAndSegue(googleBooksId: searchResult.id)
        }
    }
    
    func performSearch(searchText: String) {
        // Don't bother searching for empty text
        guard !searchText.isEmptyOrWhitespace else { displaySearchResults(GoogleBooks.SearchResultsPage.empty()); return }
        
        SVProgressHUD.show(withStatus: "Searching...")
        feedbackGenerator.prepare()
        GoogleBooks.search(searchController.searchBar.text!) { [weak self] results in
            SVProgressHUD.dismiss()
            guard let vc = self else { return }
            if !results.searchResults.isSuccess {
                vc.emptyDatasetView.setEmptyDatasetReason(.error)
            }
            else {
                vc.displaySearchResults(results)
            }
        }
    }
    
    func displaySearchResults(_ resultPage: GoogleBooks.SearchResultsPage) {
        if resultPage.searchText?.isEmptyOrWhitespace != false {
            emptyDatasetView.setEmptyDatasetReason(.noSearch)
        }
        else if !resultPage.searchResults.isSuccess {
            feedbackGenerator.notificationOccurred(.error)
            if let googleError = resultPage.searchResults.error as? GoogleBooks.GoogleError {
                Crashlytics.sharedInstance().recordError(googleError, withAdditionalUserInfo: ["GoogleErrorMessage": googleError.message])
            }
            emptyDatasetView.setEmptyDatasetReason(.error)
        }
        else if resultPage.searchResults.value!.count == 0 {
            feedbackGenerator.notificationOccurred(.warning)
            emptyDatasetView.setEmptyDatasetReason(.noResults)
        }
        else {
            feedbackGenerator.notificationOccurred(.success)
        }
        
        tableItems = resultPage.searchResults.value ?? []
        tableView.backgroundView = tableItems.isEmpty ? emptyDatasetView : nil
        tableView.reloadData()
        
        // No results should hide the toolbar. Unselecting previously selected results should disable the Add All button
        navigationController!.setToolbarHidden(tableItems.isEmpty, animated: true)
        if tableView.isEditing && tableView.indexPathsForSelectedRows?.count ?? 0 == 0 {
            addAllButton.isEnabled = false
        }
    }
    
    func presentDuplicateBookAlert(book: Book, fromSelectedIndex indexPath: IndexPath) {
        let alert = duplicateBookAlertController(goToExistingBook: { [unowned self] in
            self.presentingViewController!.dismiss(animated: true) {
                appDelegate.tabBarController.simulateBookSelection(book, allowTableObscuring: true)
            }
        }, cancel: { [unowned self] in
            self.tableView.deselectRow(at: indexPath, animated: true)
        })
        searchController.present(alert, animated: true)
    }
    
    func fetchAndSegue(googleBooksId: String) {
        UserEngagement.logEvent(.searchOnline)
        SVProgressHUD.show(withStatus: "Loading...")
        GoogleBooks.fetch(googleBooksId: googleBooksId) { resultPage in
            DispatchQueue.main.async { [weak self] in
                SVProgressHUD.dismiss()
                if let fetchResult = resultPage.result.value {
                    self?.performSegue(withIdentifier: "createReadStateSegue", sender: fetchResult.toBookMetadata())
                }
                else {
                    SVProgressHUD.showError(withStatus: "An error occurred. Please try again later.")
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard let createReadState = segue.destination as? CreateReadState, let bookMetadata = sender as? BookMetadata else { return }
        createReadState.bookMetadata = bookMetadata
        navigationController!.setToolbarHidden(true, animated: true)
    }

    @IBAction func changeSelectMode(_ sender: UIBarButtonItem) {
        tableView.setEditing(!tableView.isEditing, animated: true)
        selectModeButton.title = tableView.isEditing ? "Select Single" : "Select Many"
        if !tableView.isEditing {
            addAllButton.isEnabled = false
        }
    }
    
    @IBAction func addAllPressed(_ sender: UIBarButtonItem) {
        guard tableView.isEditing, let selectedRows = tableView.indexPathsForSelectedRows, selectedRows.count > 0 else { return }
        
        // If there is only 1 cell selected, we might as well proceed as we would in single selection mode
        guard selectedRows.count > 1 else { fetchAndSegue(googleBooksId: tableItems[selectedRows.first!.row].id); return }
        
        let alert = UIAlertController(title: "Add \(selectedRows.count) books", message: "Are you sure you want to add all \(selectedRows.count) selected books? They will be added to the 'To Read' section.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Add All", style: .default, handler: {[unowned self] _ in
            self.addMultiple(selectedRows: selectedRows)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func addMultiple(selectedRows: [IndexPath]) {
        UserEngagement.logEvent(.searchOnlineMultiple)
        SVProgressHUD.show(withStatus: "Adding...")
        let fetches = DispatchGroup()
        var lastAddedBook: Book?
        var errorCount = 0
        
        // Queue up the fetches
        for selectedIndex in selectedRows {
            fetches.enter()
            GoogleBooks.fetch(googleBooksId: tableItems[selectedIndex.row].id) { resultPage in
                DispatchQueue.main.async {
                    if let metadata = resultPage.result.value?.toBookMetadata() {
                        lastAddedBook = appDelegate.booksStore.create(from: metadata, readingInformation: BookReadingInformation.toRead())
                    }
                    else {
                        errorCount += 1
                    }
                    fetches.leave()
                }
            }
        }
        
        // On completion, dismiss this view (or show an error if they all failed)
        fetches.notify(queue: .main) { [weak self] in
            SVProgressHUD.dismiss()
            guard errorCount != selectedRows.count else {
                // If they all errored, don't dismiss - show an error
                SVProgressHUD.showError(withStatus: "An error occurred. No books were added."); return
            }
            
            self?.presentingViewController!.dismiss(animated: true) {
                if let lastAddedBook = lastAddedBook {
                    // Scroll to the last added book. This is a bit random, but better than nothing probably
                    appDelegate.tabBarController.simulateBookSelection(lastAddedBook, allowTableObscuring: false)
                }
                // Display an error if any books could not be added
                if errorCount != 0 {
                    SVProgressHUD.showInfo(withStatus: "\(selectedRows.count - errorCount) book\(selectedRows.count - errorCount == 1 ? "" : "s") successfully added; \(errorCount) book\(errorCount == 1 ? "" : "s") could not be added due to an error.")
                }
            }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        performSearch(searchText: searchBar.text ?? "")
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            displaySearchResults(GoogleBooks.SearchResultsPage.empty())
        }
    }
}

class SearchBooksEmptyDataset: UIView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!

    enum EmptySetReason {
        case noSearch
        case noResults
        case error
    }
    
    func setEmptyDatasetReason(_ reason: EmptySetReason) {
        self.reason = reason
        titleLabel.text = title
        descriptionLabel.text = descriptionString
    }
    
    func setTopDistance(_ distance: CGFloat) {
        topConstraint.constant = distance
        self.layoutIfNeeded()
    }
    
    private var reason = EmptySetReason.noSearch
    
    private var title: String {
        get {
            switch reason {
            case .noSearch:
                return "🔍 Search Books"
            case .noResults:
                return "😞 No Results"
            case .error:
                return "⚠️ Error!"
            }
        }
    }
    
    private var descriptionString: String {
        get {
            switch reason {
            case .noSearch:
                return "Search books by title, author, ISBN - or a mixture!"
            case .noResults:
                return "There were no Google Books search results. Try changing your search text."
            case .error:
                return "Something went wrong! It might be your Internet connection..."
            }
        }
    }
}

/**
 A single sectioned (at most) table view controller, backed by an array.
*/
class ArrayBackedTableController<ArrayItemType>: UITableViewController {
    var tableItems = [ArrayItemType]()
    var cellIdentifier = "cellIdentifier"
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableItems.isEmpty ? 0 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? tableItems.count : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! ArrayBackedTableCell<ArrayItemType>
        cell.updateDisplay(from: tableItems[indexPath.row])
        return cell
    }
}

class ArrayBackedTableCell<ArrayItemType>: UITableViewCell {
    func updateDisplay(from arrayItem: ArrayItemType) { }
}

/// A table cell used in the Search Online table
class SearchResultCell: ArrayBackedTableCell<GoogleBooks.SearchResult> {
    @IBOutlet weak var titleOutlet: UILabel!
    @IBOutlet weak var authorOutlet: UILabel!
    @IBOutlet weak var imageOutlet: UIImageView!
    
    private var coverImageRequest: HTTP.Request?

    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Cancel any pending cover data request task
        coverImageRequest?.cancel()

        titleOutlet.text = nil
        authorOutlet.text = nil
        imageOutlet.image = nil
    }
    
    override func updateDisplay(from arrayItem: GoogleBooks.SearchResult) {
        super.updateDisplay(from: arrayItem)

        titleOutlet.text = arrayItem.title
        authorOutlet.text = arrayItem.authors.joined(separator: ", ")
        
        guard let coverURL = arrayItem.thumbnailCoverUrl else { imageOutlet.image = #imageLiteral(resourceName: "CoverPlaceholder"); return }
        coverImageRequest = HTTP.Request.get(url: coverURL).data { [weak self] result in
            // Cancellations appear to be reported as errors. Ideally we would detect non-cancellation
            // errors (e.g. 404), and show the placeholder in those cases. For now, just make the image blank.
            guard result.isSuccess, let data = result.value else { self?.imageOutlet.image = nil; return }
            self?.imageOutlet.image = UIImage(data: data)
        }
    }
}

