import UIKit
import CoreData

/**
 Manages mapping search queries to Predicates, applying the predicates to a NSFetchedResultsController,
 and updating the results displayed in a table.
*/
class FetchedResultsFilterer<ResultType>: NSObject, UISearchResultsUpdating where ResultType: NSFetchRequestResult {
    let searchController: UISearchController
    let onChange: (() -> ())?
    
    private let fetchedResultsControllers: [NSFetchedResultsController<ResultType>]
    private let tableView: UITableView

    init(searchController: UISearchController, tableView: UITableView, fetchedResultsControllers: [NSFetchedResultsController<ResultType>], onChange: (() -> ())?) {
        self.searchController = searchController
        self.fetchedResultsControllers = fetchedResultsControllers
        self.tableView = tableView
        self.onChange = onChange
        super.init()
        
        self.searchController.searchResultsUpdater = self
    }
    
    func updateResults() {
        updateSearchResults(for: searchController)
    }
    
    func predicate(forSearchText searchText: String?) -> NSPredicate {
        fatalError("buildPredicateFrom(searchText) is not overriden")
    }

    public func updateSearchResults(for searchController: UISearchController) {
        let predicate = self.predicate(forSearchText: searchController.searchBar.text)
        
        // We shouldn't need to do anything if the predicate is the same, given that we are tracking changes.
        var anyChangedPredicates = false
        for fetchedResultsController in fetchedResultsControllers {
            if fetchedResultsController.fetchRequest.predicate != predicate {
                fetchedResultsController.fetchRequest.predicate = predicate
                try! fetchedResultsController.performFetch()
                tableView.reloadData()
                anyChangedPredicates = true
            }
        }
        if anyChangedPredicates {
            onChange?()
        }
    }

    var showingSearchResults: Bool {
        get {
            return searchController.isActive && searchController.searchBar.text?.isEmpty == false
        }
    }
    
    func dismissSearch() {
        self.searchController.isActive = false
        self.searchController.searchBar.showsCancelButton = false
        self.updateSearchResults(for: self.searchController)
    }
}
