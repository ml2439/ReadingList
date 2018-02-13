import UIKit
import CoreData

/**
 A UITableViewController which automatically updates its cells via a TableUpdaterGeneral object,
 provided the tableUpdater variable is assigned on load.
 */
class AutoUpdatingTableViewController : UITableViewController {
    var tableUpdater: GeneralTableUpdater!
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableUpdater.numberOfRows(inSection: section)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableUpdater.numberOfSections()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableUpdater.cellForRow(at: indexPath)
    }
}


/**
 Extends NSFetchedResultsControllerDelegate with methods which return number of rows and sections,
 and can configure a cell for a given IndexPath.
 */
protocol GeneralTableUpdater : NSFetchedResultsControllerDelegate {
    func numberOfSections() -> Int
    func numberOfRows(inSection section: Int) -> Int
    func cellForRow(at indexPath: IndexPath) -> UITableViewCell
    func withoutUpdates(closure: (() -> Void))
}

/**
 A cell which can be configured from a object returned from a NSFetchedResultsController.
*/
protocol ConfigurableCell {
    associatedtype ResultType : NSFetchRequestResult
    func configureFrom(_ result: ResultType)
}

/**
 A generic implementation of TableUpdaterGeneral, typed to the NSFetchedResultsController result type and the UITableViewCell type.
 Given a UITableView, an NSFetchedResultsController and a function to update Cells, can react to changed in the NSFetchedResultsController,
 and also expose the current values for the number of rows and sections, and provide a configured cell for a given IndexPath.
 */
class TableUpdater<ResultType, CellType> : NSObject, GeneralTableUpdater
where CellType : UITableViewCell, CellType: ConfigurableCell, CellType.ResultType == ResultType {
    
    let tableView: UITableView
    private let controller: NSFetchedResultsController<ResultType>
    private let cellIdentifier = String(describing: CellType.self)
    private var createdSectionIndexes = [Int]()
    
    init(table: UITableView, controller: NSFetchedResultsController<ResultType>){
        self.tableView = table
        self.controller = controller
        super.init()
        
        try! self.controller.performFetch()
        self.controller.delegate = self
    }
    
    func numberOfSections() -> Int {
        return controller.sections?.count ?? 0
    }
    
    func numberOfRows(inSection section: Int) -> Int {
        return controller.sections?[section].numberOfObjects ?? 0
    }
    
    func cellForRow(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! CellType
        cell.configureFrom(controller.object(at: indexPath))
        return cell
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        createdSectionIndexes.removeAll(keepingCapacity: false)
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange object: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
            // some weird stuff happens in iOS 9 :/
            // Be extra careful
        case .update:
            if let indexPath = indexPath,
                let newIndexPath = newIndexPath,
                indexPath != newIndexPath {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            else if let indexPath = indexPath, !createdSectionIndexes.contains(indexPath.section) {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
            createdSectionIndexes.append(sectionIndex)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        default:
            break
        }
    }
    
    func withoutUpdates(closure: (() -> Void)) {
        controller.delegate = nil
        closure()
        controller.delegate = self
    }
}
