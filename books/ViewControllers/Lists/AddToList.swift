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

/**
 A UIAlertController with a single text field input, and an OK and Cancel action. The OK button is disabled
 when the text box is empty or whitespace.
 */
class TextBoxAlertController: UIAlertController {
    convenience init(title: String, message: String? = nil, initialValue: String? = nil, placeholder: String? = nil, onOK: @escaping (String) -> ()) {
        self.init(title: title, message: message, preferredStyle: .alert)
        
        addTextField{ [unowned self] textField in
            textField.addTarget(self, action: #selector(self.textFieldDidChange), for: .editingChanged)
            textField.autocapitalizationType = .words
            textField.placeholder = placeholder
            textField.text = initialValue
        }
        addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let okAction = UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
            onOK(self.textFields![0].text!)
        }
        
        okAction.isEnabled = isValidInput(initialValue)
        addAction(okAction)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        actions[1].isEnabled = isValidInput(textField.text)
    }
    
    func isValidInput(_ input: String?) -> Bool {
        return input?.isEmptyOrWhitespace == false
    }
}

class NewListAlertController: TextBoxAlertController {
    convenience init(onOK: @escaping (String) -> ()) {
        self.init(title: "Add New List", message: "Enter a name for your list", placeholder: "Enter list name", onOK: onOK)
    }
}

class AddToList: UITableViewController {
    
    // Since this view is only brought up as a modal dispay, it is probably not necessary to implement
    // change detection via a NSFetchedResultsControllerDelegate.
    var resultsController: NSFetchedResultsController<List>!
    
    // Holds the books which are to be added to a list
    var books: [Book]!
    
    /*
     Returns the appropriate View Controller for adding a book (or books) to a list.
     If there are no lists, this will be a UIAlertController; if there are lists, this will be a UINavigationController.
     The completion action will run at the end of a list addition if a UIAlertController was returned.
    */
    static func getAppropriateVcForAddingBooksToList(_ booksToAdd: [Book], completion: (() -> ())? = nil) -> UIViewController {
        if appDelegate.booksStore.listCount() > 0 {
            let rootAddToList = Storyboard.AddToList.instantiateRoot(withStyle: .formSheet) as! UINavigationController
            (rootAddToList.viewControllers[0] as! AddToList).books = booksToAdd
            return rootAddToList
        }
        else {
            return AddToList.newListAlertController(booksToAdd, completion: completion)
        }
    }
    
    static func newListAlertController(_ books: [Book], completion: (() -> ())? = nil) -> UIAlertController {
        return NewListAlertController(onOK: { title in
            let createdList = appDelegate.booksStore.createList(name: title, type: ListType.customList)
            createdList.books = NSOrderedSet(array: books)
            appDelegate.booksStore.save()            
            completion?()
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resultsController = appDelegate.booksStore.fetchedListsController()
        try! resultsController.performFetch()
    }

    @IBAction func cancelWasPressed(_ sender: Any) { navigationController!.dismiss(animated: true) }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 { return 1 }
        return resultsController.fetchedObjects!.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // One "Add new" section, one "existing" section
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "Add to an existing list" }
        return "Or add to a new list"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExistingListCell", for: indexPath) as! ListCell

            let listObj = resultsController.object(at: indexPath)
            cell.configureFrom(listObj)
            
            // If the books are all already in this list, disable this selection
            let booksInSetAlready = NSSet(array: books).isSubset(of: listObj.books.set)
            cell.isEnabled = !booksInSetAlready
            if booksInSetAlready {
                let alreadyAddedText = books.count == 1 ? "already added" : "all already added"
                cell.detailTextLabel!.text = cell.detailTextLabel!.text! + " (\(alreadyAddedText))"
            }
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NewListCell", for: indexPath)
            cell.textLabel!.text = "Add New List"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            // Append the books to the end of the selected list
            let list = resultsController.object(at: IndexPath(row: indexPath.row, section: 0))
            list.books = NSOrderedSet(array: list.booksArray + books)
            appDelegate.booksStore.save()

            navigationController!.dismiss(animated: true)
        }
        else {
            present(AddToList.newListAlertController(books) { [unowned self] in
                self.navigationController!.dismiss(animated: true)
            }, animated: true)
        }
    }
}

extension UITableViewCell {
    var isEnabled: Bool {
        get {
            return isUserInteractionEnabled && textLabel?.isEnabled != false && detailTextLabel?.isEnabled != false
        }
        set {
            isUserInteractionEnabled = newValue
            textLabel?.isEnabled = newValue
            detailTextLabel?.isEnabled = newValue
        }
    }
}
