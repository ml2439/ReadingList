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
        let booksCopy = list.books.mutableCopy() as! NSMutableOrderedSet
        booksCopy.remove(list.booksArray[indexPath.row])
        list.books = booksCopy.copy() as! NSOrderedSet
        appDelegate.booksStore.save()
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: "Remove") { [unowned self] _, indexPath in
            self.removeBook(at: indexPath)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableView.reloadEmptyDataSet()
        }]
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { return list.booksArray.count > 1 }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // TODO
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
        return NSAttributedString(string: "No books added", attributes: [NSAttributedStringKey.font: Fonts.gillSans(ofSize: 32),
                                                                  NSAttributedStringKey.foregroundColor: UIColor.gray])
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let bodyFont = Fonts.gillSans(forTextStyle: .title2)
        let boldFont = Fonts.gillSansSemiBold(forTextStyle: .title2)
        
        let markdown = MarkdownWriter(font: bodyFont, boldFont: boldFont)
        return markdown.write("The list \"\(list.name)\" is currently empty.  To add a book to it, find a book and click **Add to List**.")
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
