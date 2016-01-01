//
//  SettingsViewController.swift
//  books
//
//  Created by Andrew Bennet on 01/12/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit

class OptionsViewController: UITableViewController {
    
    @IBOutlet weak var populateDataCell: UITableViewCell!
    var booksProcessed = 0
    
    let booksToAdd: [(isbn: String, readState: BookReadState, titleDesc: String)] =
        [("9780007232444", .Finished, "The Corrections"),
         ("9780099529125", .Finished, "Catch-22"),
         ("9780141187761", .Finished, "1984"),
         ("9780735611313", .Finished, "Code"),
         ("9780857282521", .ToRead, "The Entrepreneurial State"),
         ("9780330510936", .ToRead, "All the Pretty Horses"),
         ("9780006480419", .ToRead, "Neuromancer"),
         ("9780241950432", .Finished, "Catcher in the Rye"),
         ("9780099800200", .Finished, "Slaughterhouse 5"),
         ("9780006546061", .ToRead, "Farenheit 451"),
         ("9781442369054", .ToRead, "Steve Jobs"),
         ("9780007532766", .Finished, "Purity"),
         ("9780718197384", .ToRead, "The Price of Inequality"),
         ("9780099889809", .ToRead, "Something Happened"),
         ("9780241197790", .Reading, "The Trial")]
    
    func makeAddBookFunc(readState: BookReadState) -> ((BookMetadata?) -> Void) {
        return {
            (parsedResult: BookMetadata?) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                self.booksProcessed++
                if parsedResult != nil{
                    parsedResult!.readState = readState
                    appDelegate.booksStore.CreateBook(parsedResult!)
                }
            
                self.showMessageIfAllAdded()
            }
        }
    }
    
    func showMessageIfAllAdded() {
        if self.booksProcessed == self.booksToAdd.count{
            appDelegate.booksStore.Save()
            let alert = UIAlertController(title: "Complete", message: "\(self.booksProcessed) Books Added", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if self.tableView.cellForRowAtIndexPath(indexPath) == populateDataCell{
            booksProcessed = 0
            for bookToAdd in booksToAdd{
                GoogleBooksApiClient.SearchByIsbn(bookToAdd.isbn, callback: makeAddBookFunc(bookToAdd.readState))
            }
        }
    }
    
    
    
}