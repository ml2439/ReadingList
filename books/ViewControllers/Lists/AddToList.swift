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

class NewListAlertController: UIAlertController {
    convenience init(onOK: @escaping (String) -> ()) {
        self.init(title: "Add New List", message: "Enter a name for your list", preferredStyle: .alert)

        addTextField{ [unowned self] textField in
            textField.placeholder = "Enter list name"
            textField.addTarget(self, action: #selector(self.textFieldDidChange), for: .editingChanged)
        }
        addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let okAction = UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
            onOK(self.textFields![0].text!)
        }
        // The OK action should be disabled until there is some text
        okAction.isEnabled = false
        addAction(okAction)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        // TODO: Disallow duplicate list names?
        actions[1].isEnabled = textField.text?.isEmptyOrWhitespace == false
    }
}

class AddToList: UITableViewController {
    
    var resultsController: NSFetchedResultsController<List>!
    
    // Holds the books which are to be added to a list
    var books: [Book]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resultsController = appDelegate.booksStore.fetchedListsController()
        try! resultsController.performFetch()
    }
    
    @IBAction func cancelWasPressed(_ sender: Any) { navigationController!.dismiss(animated: true) }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            let listCount = resultsController.fetchedObjects!.count
            return listCount == 0 ? 1 : listCount
        }
        return 1
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // One "Add new" section, one "existing" section
        return resultsController.fetchedObjects!.count == 0 ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Add to \(section == 1 ? "new" : "an existing") list"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 || resultsController.fetchedObjects!.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NewListCell", for: indexPath)
            cell.textLabel!.text = "Add New List"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExistingListCell", for: indexPath) as! ListCell

            // The fetched results from the controller are all in section 0, so adjust the provided
            // index path (which will be for section 1).
            let listObj = resultsController.object(at: indexPath)
            cell.configureFrom(listObj)

            // If the books are all already in this list, disable this selection
            let booksInSetAlready = NSSet(array: books).isSubset(of: listObj.books.set)
            cell.textLabel!.isEnabled = !booksInSetAlready
            cell.detailTextLabel!.isEnabled = !booksInSetAlready
            cell.isUserInteractionEnabled = !booksInSetAlready
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let list = resultsController.object(at: IndexPath(row: indexPath.row, section: 0))
            
            // Append the books to the end of the selected list.
            let mutableBooksSet = list.books.mutableCopy() as! NSMutableOrderedSet
            mutableBooksSet.addObjects(from: books)
            list.books = mutableBooksSet.copy() as! NSOrderedSet
            appDelegate.booksStore.save()
            navigationController!.dismiss(animated: true)
        }
        else {
            let newListAlert = NewListAlertController(onOK: { title in
                let createdList = appDelegate.booksStore.createList(name: title, type: ListType.customList)
                createdList.books = NSOrderedSet(array: self.books)
                appDelegate.booksStore.save()
                self.navigationController!.dismiss(animated: true)
            })
            present(newListAlert, animated: true){
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}
