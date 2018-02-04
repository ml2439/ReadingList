//
//  ListBookTable.swift
//  books
//
//  Created by Andrew Bennet on 21/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import DZNEmptyDataSet

class ListBookTable: UITableViewController {
    
    var list: List!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = list.name
        navigationItem.rightBarButtonItem = editButtonItem
        
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        
        registerForSaveNotifications()
    }
    
    func registerForSaveNotifications() {
        // Watch for changes in the managed object context, in order to update the table
        NotificationCenter.default.addObserver(self, selector: #selector(saveOccurred(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: appDelegate.booksStore.managedObjectContext)
    }
    
    func withoutAutomaticUpdates(_ code: () -> ()) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
        code()
        registerForSaveNotifications()
    }
    
    @objc func saveOccurred(_ notification: Notification) {
        guard let userInfo = (notification as NSNotification).userInfo else { return }
        
        let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet ?? NSSet()
        guard deletedObjects.contains(list) != true else {
            // If the list was deleted, pop back. This can't happen through any normal means at the moment.
            navigationController!.popViewController(animated: false)
            return
        }
        
        // Reload the data
        tableView.reloadData()
    }
        
    override func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else { return 0 }
        return list.booksArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookTableViewCell") as! BookTableViewCell
        cell.configureFrom(list.booksArray[indexPath.row])
        return cell
    }
    
    private func removeBook(at indexPath: IndexPath) {
        var books = list.booksArray
        books.remove(at: indexPath.row)
        list.books = NSOrderedSet(array: books)
        appDelegate.booksStore.save()
        
        UserEngagement.logEvent(.removeBookFromList)
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: "Remove") { [unowned self] _, indexPath in
            self.withoutAutomaticUpdates {
                self.removeBook(at: indexPath)
            }

            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableView.reloadEmptyDataSet()
        }]
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { return list.booksArray.count > 1 }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else { return }

        var books = list.booksArray
        let movedBook = books.remove(at: sourceIndexPath.row)
        books.insert(movedBook, at: destinationIndexPath.row)
        list.books = NSOrderedSet(array: books)
        withoutAutomaticUpdates {
            appDelegate.booksStore.save()
        }
        
        UserEngagement.logEvent(.reorederList)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let detailsViewController = (segue.destination as? UINavigationController)?.topViewController as? BookDetails {
            let selectedIndex = tableView.indexPath(for: sender as! UITableViewCell)!
            detailsViewController.book = list.booksArray[selectedIndex.row]
        }
    }
}

extension ListBookTable: DZNEmptyDataSetSource {
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return StandardEmptyDataset.title(withText: /*🕳️*/"✨ Empty List")
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
