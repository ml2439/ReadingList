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

class ListCell: UITableViewCell, ConfigurableCell {
    typealias ResultType = List
    
    func configureFrom(_ result: List) {
        textLabel!.text = result.name
        detailTextLabel!.text = "\(result.booksArray.count) book\(result.booksArray.count == 1 ? "" : "s")"
    }
}

class Organise: AutoUpdatingTableViewController {

    var resultsController: NSFetchedResultsController<List>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.emptyDataSetSource = self
        
        resultsController = appDelegate.booksStore.fetchedListsController()
        tableUpdater = TableUpdater<List, ListCell>(table: tableView, controller: resultsController)
        
        navigationItem.leftBarButtonItem = editButtonItem
        try! resultsController.performFetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        clearsSelectionOnViewWillAppear = true
        if #available(iOS 11.0, *) {
            navigationController!.navigationBar.prefersLargeTitles = UserSettings.useLargeTitles.value
        }
    }

    @IBAction func addWasPressed(_ sender: Any) {
        present(NewListAlertController(onOK: {
            appDelegate.booksStore.createList(name: $0, type: .customList)
            appDelegate.booksStore.save()
        }), animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        
        let confirmDelete = UIAlertController(title: "Confirm delete", message: nil, preferredStyle: .actionSheet)
            
        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive){ [unowned self] _ in
            appDelegate.booksStore.deleteObject(self.resultsController.object(at: indexPath))
            appDelegate.booksStore.save()
            self.tableView.setEditing(false, animated: true)
        })
        confirmDelete.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(confirmDelete, animated: true, completion: nil)
    }
}

extension Organise: DZNEmptyDataSetSource {
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let titleText = "🗂️ Organise"
        
        return NSAttributedString(string: titleText, attributes: [NSAttributedStringKey.font: Fonts.gillSans(ofSize: 32), NSAttributedStringKey.foregroundColor: UIColor.gray])
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
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let bodyFont = Fonts.gillSans(forTextStyle: .title2)
        let boldFont = Fonts.gillSansSemiBold(forTextStyle: .title2)
        
        let markdown = MarkdownWriter(font: bodyFont, boldFont: boldFont)
        return markdown.write("Create your own lists to organise your books. Any lists you create will show up here.")
    }
}
