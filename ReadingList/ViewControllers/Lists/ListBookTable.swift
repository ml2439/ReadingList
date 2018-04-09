import Foundation
import UIKit
import CoreData
import DZNEmptyDataSet

class ListBookTable: UITableViewController {
    
    var list: List!
    var ignoreNotifications = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(BookTableViewCell.self), forCellReuseIdentifier: String(describing: BookTableViewCell.self))
        navigationItem.title = list.name
        navigationItem.rightBarButtonItem = editButtonItem
        
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        
        registerForSaveNotifications()
        
        if #available(iOS 11.0, *) {
            monitorLargeTitleSetting()
        }
        monitorThemeSetting()
    }
    
    func registerForSaveNotifications() {
        // Watch for changes in the managed object context, in order to update the table
        NotificationCenter.default.addObserver(self, selector: #selector(changeOccurred(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: list.managedObjectContext!)
    }
    
    @objc func changeOccurred(_ notification: Notification) {
        guard !ignoreNotifications else { return }
        guard let userInfo = (notification as NSNotification).userInfo else { return }
        
        let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet ?? NSSet()
        guard !deletedObjects.contains(list) else {
            // If the list was deleted, pop back. This can't happen through any normal means at the moment.
            navigationController!.popViewController(animated: false)
            return
        }
        
        // Reload the data
        tableView.reloadData()
    }
    
    func performUIEdit(_ block: () -> ()) {
        ignoreNotifications = true
        block()
        ignoreNotifications = false
    }
        
    override func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else { return 0 }
        return list.books.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: BookTableViewCell.self), for: indexPath) as! BookTableViewCell
        let book = list.books.object(at: indexPath.row) as! Book
        cell.initialise(withTheme: UserSettings.theme.value)
        cell.configureFrom(book, includeReadDates: false)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showDetail", sender: indexPath)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return !tableView.isEditing
    }
    
    private func removeBook(at indexPath: IndexPath) {
        list.removeBooks(NSSet(object: list.books[indexPath.row]))
        list.managedObjectContext!.saveAndLogIfErrored()
        UserEngagement.logEvent(.removeBookFromList)
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: "Remove") { [unowned self] _, indexPath in
            self.performUIEdit {
                self.removeBook(at: indexPath)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            self.tableView.reloadEmptyDataSet()
        }]
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { return list.books.count > 1 }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else { return }
        performUIEdit {
            var books = list.books.map{($0 as! Book)}
            let movedBook = books.remove(at: sourceIndexPath.row)
            books.insert(movedBook, at: destinationIndexPath.row)
            list.books = NSOrderedSet(array: books)
            list.managedObjectContext!.saveAndLogIfErrored()
        }
        UserEngagement.logEvent(.reorederList)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let detailsViewController = (segue.destination as? UINavigationController)?.topViewController as? BookDetails {
            let senderIndex = sender as! IndexPath
            detailsViewController.book = (list.books.object(at: senderIndex.row) as! Book)
        }
    }
}

extension ListBookTable: DZNEmptyDataSetSource {
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return StandardEmptyDataset.title(withText: "✨ Empty List")
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return StandardEmptyDataset.description(withMarkdownText: "The list \"\(list.name)\" is currently empty.  To add a book to it, find a book and click **Add to List**.")
    }
}

extension ListBookTable: DZNEmptyDataSetDelegate {
    func emptyDataSetWillAppear(_ scrollView: UIScrollView!) {
        navigationItem.rightBarButtonItem = nil
    }
    
    func emptyDataSetDidDisappear(_ scrollView: UIScrollView!) {
        navigationItem.rightBarButtonItem = editButtonItem
    }
}
