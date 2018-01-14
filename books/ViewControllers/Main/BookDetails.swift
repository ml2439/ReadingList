//
//  BookDetails.swift
//  books
//
//  Created by Andrew Bennet on 01/01/2018.
//  Copyright © 2018 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class BookDetails: UIViewController, UIScrollViewDelegate {
    @IBOutlet weak var cover: UIImageView!
    @IBOutlet weak var bookTitle: UILabel!
    @IBOutlet weak var author: UILabel!
    @IBOutlet weak var bookDescription: UILabel!
    /*@IBOutlet weak var pageCount: UILabel!
    @IBOutlet weak var isbn: UILabel!
    @IBOutlet weak var published: UILabel!
    @IBOutlet weak var categories: UILabel!*/
    @IBOutlet weak var readStateLabel: UILabel!
    @IBOutlet weak var readTimeLabel: UILabel!
    @IBOutlet weak var dateAdded: UILabel!
    
    @IBOutlet weak var dateStarted: UILabel!
    @IBOutlet weak var dateFinished: UILabel!
    
    @IBOutlet weak var changeReadStateButton: StartFinishButton!
    
    var didShowNavigationItemTitle = false
    var shouldTruncateLongDescriptions = true
    
    var parentSplitViewController: SplitViewController? {
        get { return appDelegate.tabBarController.selectedViewController as? SplitViewController }
    }
    
    func setViewEnabled(enabled: Bool) {
        // Show the whole view and nav bar buttons
        view.isHidden = !enabled
        //navigationItem.rightBarButtonItems?.forEach({$0.toggleHidden(hidden: true)})
    }
    
    var book: Book? {
        didSet { setupViewFromBook() }
    }
    
    func setupViewFromBook() {
        guard let book = book else {
            // Hide the whole view and nav bar buttons
            setViewEnabled(enabled: false); return
        }
        
        setViewEnabled(enabled: true)
        
        if let coverData = book.coverImage, let image = UIImage(data: coverData) {
            cover.image = image
        }
        else {
            cover.image = #imageLiteral(resourceName: "CoverPlaceholder")
        }

        bookTitle.text = book.title
        (navigationItem.titleView as! UINavigationBarLabel).setTitle(book.title)

        func setTextOrHideParentAndNext(_ label: UILabel, _ string: String?) {
            label.text = string
            label.superview!.isHidden = string == nil
            label.superview!.nextSibling?.isHidden = string == nil
        }
        
        author.text = book.authorsFirstLast
        setTextOrHideParentAndNext(bookDescription, book.bookDescription)
        
        let dayCount = book.readState == .toRead ? 0 : (NSCalendar.current.dateComponents([.day], from: book.startedReading!.startOfDay(), to: (book.finishedReading ?? Date()).startOfDay()).day ?? 0)
        let readTime: String
        if dayCount <= 0 && book.readState == .finished {
            readTime = "Within\na day"
        }
        else if dayCount == 1 {
            readTime =  "1 day"
        }
        else {
            readTime = "\(dayCount) days"
        }
        
        // Reading Log
        switch book.readState {
        case .toRead:
            readStateLabel.text = "To Read"
            changeReadStateButton.setState(.start)
        case .reading:
            readStateLabel.text = "Currently\nReading"
            changeReadStateButton.setState(.finish)
        case .finished:
            readStateLabel.text = "Finished"
            changeReadStateButton.setState(.none)
        }
        //readStateLabel.superview!.sizeToFit()
        
        if book.readState == .toRead {
            readTimeLabel.superview!.isHidden = true
        }
        else {
            readTimeLabel.text = readTime
            readTimeLabel.superview!.isHidden = false
            readTimeLabel.superview!.layoutSubviews()
            
            
            //readTimeLabel.superview!.sizeToFit()
        }
        
        // Information table
        /*setTextOrHideParentAndNext(pageCount, book.pageCount?.stringValue)
        setTextOrHideParentAndNext(isbn, book.isbn13)
        setTextOrHideParentAndNext(published, book.publicationDate?.toPrettyString())
        setTextOrHideParentAndNext(categories, book.subjectsArray.map{$0.name}.joined(separator: "; "))*/
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        
        // Initialise the view so that by default a blank page is shown.
        // This is required for starting the app in split-screen mode, where this view is
        // shown without any books being selected.
        setViewEnabled(enabled: false)
        
        // Listen for taps on the book description, which should remove any truncation
        let tap = UITapGestureRecognizer(target: self, action: #selector(seeMoreDescription))
        bookDescription.superview!.addGestureRecognizer(tap)
        
        // A custom title view is required for animation
        navigationItem.titleView = UINavigationBarLabel()
        navigationItem.titleView!.isHidden = true

        // Watch for changes in the managed object context
        NotificationCenter.default.addObserver(self, selector: #selector(bookChanged(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: appDelegate.booksStore.managedObjectContext)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let truncationViews = bookDescription.siblings
        
        // If we should not be truncating long descriptions, hide the siblings of the description label (which are the see more
        // button and a spacer view)
        guard shouldTruncateLongDescriptions else {
            truncationViews.forEach{$0.isHidden = true}
            return
        }
        
        if truncationViews.first!.isHidden == bookDescription.isTruncated {
            truncationViews.forEach{$0.isHidden = !bookDescription.isTruncated}
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let navController = segue.destination as? UINavigationController
        if let editBookController = navController?.viewControllers.first as? EditBook {
            editBookController.bookToEdit = book
        }
        else if let changeReadState = navController?.viewControllers.first as? EditReadState {
            changeReadState.bookToEdit = book
        }
    }
    
    @objc func seeMoreDescription() {
        guard shouldTruncateLongDescriptions else { return }
        
        // We cannot just set isHidden to true here, because we cannot be sure whether the relayout will be called before or after
        // the description label starts reporting isTruncated = false.
        // Instead, store the knowledge that the button should be hidden here; when layout is called, if the button is disabled it will be hidden.
        shouldTruncateLongDescriptions = false
        bookDescription.numberOfLines = 0
        
        // Relaying out the parent stackview is required to adjust the space between the separator and the description label
        (bookDescription.superview!.superview as! UIStackView).layoutIfNeeded()
    }
    
    @objc func bookChanged(_ notification: Notification) {
        guard let book = book, let userInfo = (notification as NSNotification).userInfo else { return }
        
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? NSSet, updatedObjects.contains(book) {
            // If the book was updated, update this page.
            setupViewFromBook()
        }
        else if let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet, deletedObjects.contains(book) {
            // If the book was deleted, set our book to nil and update this page
            self.book = nil
            
            // Pop back to the book table if necessary
            parentSplitViewController?.masterNavigationController.popToRootViewController(animated: false)
        }
    }

    @IBAction func changeReadStateButtonWasPressed(_ sender: BorderedButton) {
        guard let book = book, book.readState == .toRead || book.readState == .reading else { return }

        let readingInfo: BookReadingInformation
        if book.readState == .toRead {
            readingInfo = BookReadingInformation.reading(started: Date(), currentPage: nil)
        }
        else {
            readingInfo = BookReadingInformation.finished(started: book.startedReading!, finished: Date())
        }
        appDelegate.booksStore.update(book: book, withReadingInformation: readingInfo)
        
        UserEngagement.logEvent(.transitionReadState)
        UserEngagement.onReviewTrigger()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // 18 is the padding between the main stack view and the top. This should be determined programatically
        // if any of the layout constraints from the title to the top become more complex
        let threshold = bookTitle.frame.maxY + 18 - scrollView.univeralContentInset.top

        if didShowNavigationItemTitle != (scrollView.contentOffset.y >= threshold) {
            // Changes to the title view are to be animated
            let fadeTextAnimation = CATransition()
            fadeTextAnimation.duration = 0.2
            fadeTextAnimation.type = kCATransitionFade
            
            navigationItem.titleView!.layer.add(fadeTextAnimation, forKey: nil)
            (navigationItem.titleView as! UILabel).isHidden = didShowNavigationItemTitle
            didShowNavigationItemTitle = !didShowNavigationItemTitle
        }
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        get {
            guard let book = book else { return [UIPreviewActionItem]() }
            
            var previewActions = [UIPreviewActionItem]()
            if book.readState == .toRead {
                previewActions.append(UIPreviewAction(title: "Start", style: .default){ _,_ in
                    book.transistionToReading()
                })
            }
            else if book.readState == .reading {
                previewActions.append(UIPreviewAction(title: "Finish", style: .default){ _,_ in
                    book.transistionToFinished()
                })
            }
            previewActions.append(UIPreviewAction(title: "Delete", style: .destructive) { _,_ in
                book.delete()
            })
            return previewActions
        }
    }
}

class StartFinishButton: BorderedButton {
    enum State {
        case start
        case finish
        case none
    }
    
    func setState(_ state: State) {
        switch state {
        case .start:
            isHidden = false
            setColor(UIColor.buttonBlue)
            setTitle("START", for: .normal)
        case .finish:
            isHidden = false
            setColor(UIColor.flatGreen)
            setTitle("FINISH", for: .normal)
        case .none:
            isHidden = true
        }
    }
}

extension UIView {
    var nextSibling: UIView? {
        get {
            guard let views = superview?.subviews else { return nil }
            let thisIndex = views.index(of: self)!
            guard thisIndex + 1 < views.count else { return nil }
            return views[thisIndex + 1]
        }
    }
    
    var siblings: [UIView] {
        get {
            guard let views = superview?.subviews else { return [] }
            return views.filter{ $0 != self }
        }
    }
}
