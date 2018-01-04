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
    @IBOutlet weak var pageCount: UILabel!
    @IBOutlet weak var isbn: UILabel!
    @IBOutlet weak var published: UILabel!
    @IBOutlet weak var categories: UILabel!
    @IBOutlet weak var readStateLabel: UILabel!
    @IBOutlet weak var changeReadStateButton: BorderedButton!
    @IBOutlet weak var descriptionSeeMore: UIButton!
    
    var didShowNavigationItemTitle = false
    
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
        let titleLabel = (navigationItem.titleView as! UILabel)
        titleLabel.text = book.title
        titleLabel.sizeToFit()

        author.text = book.authorsFirstLast
        bookDescription.setTextOrHideParent(book.bookDescription)
        
        // Reading Log
        switch book.readState {
        case .toRead:
            readStateLabel.text = "📚 To Read"
            changeReadStateButton.isHidden = false
            changeReadStateButton.setColor(UIColor.buttonBlue)
            changeReadStateButton.setTitle("START", for: .normal)
        case .reading:
            readStateLabel.text = "📖 Currently Reading"
            changeReadStateButton.isHidden = false
            changeReadStateButton.setColor(UIColor.flatGreen)
            changeReadStateButton.setTitle("FINISH", for: .normal)
        case .finished:
            readStateLabel.text = "🎉 Finished"
            changeReadStateButton.isHidden = true
        }
        
        // Information table
        pageCount.setTextOrHideParent(book.pageCount?.stringValue)
        isbn.setTextOrHideParent(book.isbn13)
        published.setTextOrHideParent(book.publicationDate?.toPrettyString())
        categories.setTextOrHideParent(nil)
    }
    
    override func viewDidLoad() {
        view.backgroundColor = UIColor.white
        
        // Initialise the view so that by default a blank page is shown.
        // This is required for starting the app in split-screen mode, where this view is
        // shown without any books being selected.
        setViewEnabled(enabled: false)
        
        // Set rounded corners on the book cover image
        cover.layer.cornerRadius = 4
        cover.layer.masksToBounds = true
        
        // A custom title view is required for animation
        let titleLabelView = UILabel(frame: CGRect.zero)
        titleLabelView.backgroundColor = .clear
        titleLabelView.textAlignment = .center
        titleLabelView.textColor = UINavigationBar.appearance().tintColor
        titleLabelView.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabelView.isHidden = true
        navigationItem.titleView = titleLabelView

        // Watch for changes in the managed object context
        NotificationCenter.default.addObserver(self, selector: #selector(bookChanged(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: appDelegate.booksStore.managedObjectContext)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // If the seeMore button has been pressed, is will be disabled now which means it should be hidden at this point
        guard descriptionSeeMore.isEnabled else { descriptionSeeMore.isHidden = true; return }
        
        if descriptionSeeMore.isHidden == bookDescription.isTruncated {
            descriptionSeeMore.isHidden = !bookDescription.isTruncated
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
    
    @IBAction func seeMoreDescriptionPressed(_ sender: UIButton) {
        // We use the Enabled state to indicate whether the control should be shown or not. We cannot just set isHidden to true, because
        // we cannot be sure whether the relayout will be called before or after the description label starts reporting isTruncated = false.
        // Instead, store the knowledge that the button should be hidden here; when layout is called, if the button is disabled it will be hidden.
        descriptionSeeMore.isEnabled = false
        bookDescription.numberOfLines = 0
        
        // Relaying out the parent stackview is required to adjust the space between the separator and the description label
        bookDescription.superview!.superview!.layoutIfNeeded()
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
        var threshold: CGFloat = bookTitle.frame.maxY + 18
        if #available(iOS 11.0, *) {
            threshold -= scrollView.adjustedContentInset.top
        }
        else {
            threshold -= scrollView.contentInset.top
        }

        let titleIsBelowNav = scrollView.contentOffset.y >= threshold
        if titleIsBelowNav != didShowNavigationItemTitle {
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

fileprivate extension UILabel {
    func setTextOrHideParent(_ string: String?) {
        text = string
        superview!.isHidden = string == nil
    }
}
