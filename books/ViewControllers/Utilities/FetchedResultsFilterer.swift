import UIKit
import CoreData

/**
 Manages mapping search queries to Predicates, applying the predicates to a NSFetchedResultsController,
 and updating the results displayed in a table.
*/
class FetchedResultsFilterer<ResultType, PredicateBuilderType>: NSObject, UISearchResultsUpdating where ResultType : NSFetchRequestResult, PredicateBuilderType : SearchPredicateBuilder {
    let searchController: UISearchController
    let predicateBuilder: PredicateBuilderType
    let onChange: (() -> ())?
    
    private let fetchedResultsController: NSFetchedResultsController<ResultType>
    private let tableView: UITableView

    init(uiSearchController: UISearchController, tableView: UITableView, fetchedResultsController: NSFetchedResultsController<ResultType>, predicateBuilder: PredicateBuilderType, onChange: (() -> ())?) {
        self.searchController = uiSearchController
        self.fetchedResultsController = fetchedResultsController
        self.tableView = tableView
        self.predicateBuilder = predicateBuilder
        self.onChange = onChange
        super.init()
        
        self.searchController.searchResultsUpdater = self
    }
    
    func updateResults() {
        updateSearchResults(for: searchController)
    }

    public func updateSearchResults(for searchController: UISearchController) {
        let predicate = predicateBuilder.buildPredicateFrom(searchText: searchController.searchBar.text)
        
        // We shouldn't need to do anything if the predicate is the same, given that we are tracking changes.
        if fetchedResultsController.fetchRequest.predicate != predicate {
            fetchedResultsController.fetchRequest.predicate = predicate
            try? fetchedResultsController.performFetch()
            tableView.reloadData()
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

protocol SearchPredicateBuilder {
    func buildPredicateFrom(searchText: String?) -> NSPredicate
}
