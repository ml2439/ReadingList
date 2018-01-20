//
//  Lists.swift
//  books
//
//  Created by Andrew Bennet on 18/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class AddToList: UITableViewController {
    
    var resultsController: NSFetchedResultsController<List>!
    var books: [Book]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resultsController = appDelegate.booksStore.fetchedListsController()
        try! resultsController.performFetch()
    }
    
    @IBAction func cancelWasPressed(_ sender: Any) {
        navigationController!.dismiss(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : resultsController.fetchedObjects!.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // One "Add new" section, one "existing" section
        return resultsController.fetchedObjects!.count == 0 ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Add to new list"
        }
        else {
            return "Add to an existing list"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)
        if indexPath.section == 0 {
            cell.textLabel!.text = "Add New List"
            cell.accessoryType = .disclosureIndicator
        }
        else {
            // The fetched results from the controller are all in section 0, so adjust the provided
            // index path (which will be for section 1).
            let listObj = resultsController.object(at: IndexPath(row: indexPath.row, section: 0))
            cell.textLabel!.text = listObj.name
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let alert = UIAlertController(title: "Add New List", message: "Enter a name for your list", preferredStyle: UIAlertControllerStyle.alert)
            alert.addTextField{ textField in
                textField.placeholder = "Enter list name"
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
                let textField = alert.textFields![0] as UITextField
                let createdList = appDelegate.booksStore.createList(name: textField.text!, type: ListType.customList)
                createdList.books = NSOrderedSet(array: self.books)
                appDelegate.booksStore.save()
                self.navigationController!.dismiss(animated: true)
            })

            present(alert, animated: true)
        }
        else {
            let list = resultsController.object(at: IndexPath(row: indexPath.row, section: 0))
            print(list.name)
        }
    }
}
