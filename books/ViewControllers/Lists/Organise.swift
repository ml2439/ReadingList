//
//  Organise.swift
//  books
//
//  Created by Andrew Bennet on 20/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import DZNEmptyDataSet

class Organise: AutoUpdatingTableViewController {

    var resultsController: NSFetchedResultsController<List>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
        
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        
        resultsController = appDelegate.booksStore.fetchedListsController()
        tableUpdater = TableUpdater<List, ListCell>(table: tableView, controller: resultsController)
        try! resultsController.performFetch()
        
        navigationItem.leftBarButtonItem = editButtonItem
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [
            UITableViewRowAction(style: .destructive, title: "Delete"){ [unowned self] _, indexPath in
                self.deleteList(forRowAt: indexPath)
            },
            UITableViewRowAction(style: .normal, title: "Rename"){ [unowned self] _, indexPath in
                self.setEditing(false, animated: true)
                let list = self.resultsController.object(at: indexPath)
                
                let existingListNames = appDelegate.booksStore.getAllLists().map{$0.name}
                let renameListAlert = TextBoxAlertController(title: "Rename List", message: "Choose a new name for this list", initialValue: list.name, placeholder: "New list name", textValidator: { listName in
                        guard let listName = listName, !listName.isEmptyOrWhitespace else { return false }
                        return listName == list.name || !existingListNames.contains(listName)
                    }, onOK: {
                        list.name = $0!
                        appDelegate.booksStore.save()
                    }
                )
                
                self.present(renameListAlert, animated: true)
            }
        ]
    }
    
    func deleteList(forRowAt indexPath: IndexPath) {
        let confirmDelete = UIAlertController(title: "Confirm delete", message: nil, preferredStyle: .actionSheet)
            
        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive){ [unowned self] _ in
            appDelegate.booksStore.deleteObject(self.resultsController.object(at: indexPath))
            appDelegate.booksStore.save()
            
            UserEngagement.logEvent(.deleteList)

            // When the table goes from 1 row to 0 rows in the single section, the section header remains unless the table is reloaded
            if self.tableView.numberOfRows(inSection: 0) == 0 {
                self.tableView.reloadData()
            }
            self.tableView.setEditing(false, animated: true)
        })
        confirmDelete.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popPresenter = confirmDelete.popoverPresentationController {
            let cell = self.tableView.cellForRow(at: indexPath)!
            popPresenter.sourceRect = cell.frame
            popPresenter.sourceView = self.tableView
            popPresenter.permittedArrowDirections = .any
        }
        present(confirmDelete, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        let listCount = resultsController.sections?[0].numberOfObjects ?? 0
        return listCount == 0 ? nil : "Your lists"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let listBookTable = segue.destination as? ListBookTable {
            listBookTable.list = resultsController.object(at: tableView.indexPath(for: (sender as! UITableViewCell))!)
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // No segue in edit mode
        return !tableView.isEditing
    }
}

extension Organise: DZNEmptyDataSetSource {
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return StandardEmptyDataset.title(withText: "🗂️ Organise")
    }

    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return StandardEmptyDataset.description(withMarkdownText: "Create your own lists to organise your books.  To create a new list, tap **Add To List** when viewing a book.")
    }

    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        // The large titles make the empty data set look weirdly low down. Adjust this,
        // by - fairly randomly - the height of the nav bar
        if #available(iOS 11.0, *), navigationController!.navigationBar.prefersLargeTitles {
            return -navigationController!.navigationBar.frame.height
        }
        else {
            return 0
        }
    }
}

extension Organise: DZNEmptyDataSetDelegate {
    func emptyDataSetDidAppear(_ scrollView: UIScrollView!) {
        navigationItem.leftBarButtonItem = nil
    }
    
    func emptyDataSetDidDisappear(_ scrollView: UIScrollView!) {
        navigationItem.leftBarButtonItem = editButtonItem
    }
}


class ListCell: UITableViewCell, ConfigurableCell {
    typealias ResultType = List
    
    func configureFrom(_ result: List) {
        textLabel!.text = result.name
        detailTextLabel!.text = "\(result.booksArray.count) book\(result.booksArray.count == 1 ? "" : "s")"
    }
}
