import Foundation
import UIKit
import CoreData

protocol TableViewDataSourceDelegate: class {
    associatedtype Object
    associatedtype Cell: UITableViewCell
    func configure(_ cell: Cell, for object: Object)
}

class TableViewDataSource<Result: NSFetchRequestResult, Delegate: TableViewDataSourceDelegate>: NSObject, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    
    typealias Object = Delegate.Object
    typealias Cell = Delegate.Cell
    
    required init(tableView: UITableView, cellIdentifier: String, fetchedResultsController: NSFetchedResultsController<Result>, delegate: Delegate, onChange: (() -> ())? = nil) {
        self.tableView = tableView
        self.cellIdentifier = cellIdentifier
        self.fetchedResultsController = fetchedResultsController
        self.delegate = delegate
        self.onChange = onChange
        super.init()

        try! fetchedResultsController.performFetch()
        fetchedResultsController.delegate = self
        tableView.dataSource = self
    }
    
    fileprivate let tableView: UITableView
    let fetchedResultsController: NSFetchedResultsController<Result>
    fileprivate weak var delegate: Delegate!
    fileprivate let cellIdentifier: String
    fileprivate let onChange: (() -> ())?
    
    func object(at indexPath: IndexPath) -> Object {
        return fetchedResultsController.object(at: indexPath) as! Object
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections!.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections![section].numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = fetchedResultsController.object(at: indexPath) as! Object
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! Cell
        delegate.configure(cell, for: object)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return fetchedResultsController.sections![section].name
    }
    
    func withoutUpdates(_ block: () -> ()) {
        fetchedResultsController.delegate = nil
        block()
        fetchedResultsController.delegate = self
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        createdSectionIndexes.removeAll(keepingCapacity: false)
        tableView.beginUpdates()
    }

    private var createdSectionIndexes = [Int]()
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange object: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        // some weird stuff happens in iOS 9 :/
        // Be extra careful
        // TODO: Is this still necessary?
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
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        onChange?()
        tableView.endUpdates()
    }
}
