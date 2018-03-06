import Foundation
import UIKit
import CoreData

class AddToList: UITableViewController {
    
    // Since this view is only brought up as a modal dispay, it is probably not necessary to implement
    // change detection via a NSFetchedResultsControllerDelegate.
    var resultsController: NSFetchedResultsController<List>!
    
    // Holds the books which are to be added to a list. The set form is just for convenience.
    var books: [Book]! {
        didSet {
            booksSet = NSSet(array: books)
        }
    }
    var booksSet: NSSet!
    
    // When the add-to-list operation is complete, this callback will be called
    var onCompletion: (() -> ())?
    
    /*
     Returns the appropriate View Controller for adding a book (or books) to a list.
     If there are no lists, this will be a UIAlertController; if there are lists, this will be a UINavigationController.
     The completion action will run at the end of a list addition if a UIAlertController was returned.
    */
    static func getAppropriateVcForAddingBooksToList(_ booksToAdd: [Book], completion: (() -> ())? = nil) -> UIViewController {
        let listCount = NSManagedObject.fetchRequest(List.self, limit: 1)
        if try! PersistentStoreManager.container.viewContext.count(for: listCount) > 0 {
            let rootAddToList = Storyboard.AddToList.instantiateRoot(withStyle: .formSheet) as! UINavigationController
            let addToList = (rootAddToList.viewControllers[0] as! AddToList)
            addToList.books = booksToAdd
            addToList.onCompletion = completion
            return rootAddToList
        }
        else {
            return AddToList.newListAlertController(booksToAdd, completion: completion)
        }
    }
    
    static func newListAlertController(_ books: [Book], completion: (() -> ())? = nil) -> UIAlertController {
        let existingListNames = List.names(fromContext: PersistentStoreManager.container.viewContext)

        func textValidator(listName: String?) -> Bool {
            guard let listName = listName, !listName.isEmptyOrWhitespace else { return false }
            return !existingListNames.contains(listName)
        }

        return TextBoxAlertController(title: "Add New List", message: "Enter a name for your list", placeholder: "Enter list name", textValidator: textValidator, onOK: { title in
            let createdList = List(context: PersistentStoreManager.container.viewContext, name: title!)
            createdList.books = NSOrderedSet(array: books)
            try! PersistentStoreManager.container.viewContext.save()
            completion?()
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let fetchRequest = NSManagedObject.fetchRequest(List.self, batch: 40)
        fetchRequest.sortDescriptors = [NSSortDescriptor(\List.name)]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: PersistentStoreManager.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExistingListCell", for: indexPath)
            let listObj = resultsController.object(at: indexPath)
            cell.textLabel!.text = listObj.name
            cell.detailTextLabel!.text = "\(listObj.books.count) book\(listObj.books.count == 1 ? "" : "s")"

            let booksInThisList = listObj.books.set
            
            // If any of the books are already in this list:
            // FUTURE: Check whether this is firing a lot of faults
            if booksSet.intersects(booksInThisList) {
                var alreadyAddedText: String
                
                // Disable the cell is they are *all* already in the list
                let allAlreadyAdded = booksSet.isSubset(of: booksInThisList)
                cell.isEnabled = !allAlreadyAdded
                if allAlreadyAdded {
                    alreadyAddedText = books.count == 1 ? "already added" : "all already added"
                }
                else {
                    let overlapSet = booksSet.mutableCopy() as! NSMutableSet
                    overlapSet.intersect(booksInThisList)
                    alreadyAddedText = "\(overlapSet.count) already added" // TODO: think of better wording?
                }
                
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
            list.managedObjectContext!.performAndSave {
                list.addBooks(NSOrderedSet(array: self.books))
            }

            navigationController!.dismiss(animated: true, completion: onCompletion)
        }
        else {
            present(AddToList.newListAlertController(books) { [unowned self] in
                self.navigationController!.dismiss(animated: true, completion: self.onCompletion)
            }, animated: true)
        }
    }
}
