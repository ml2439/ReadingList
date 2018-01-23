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

    @IBOutlet weak var bookDescription: UILabel!
    @IBOutlet weak var titleAndAuthorStack: UIStackView!
    @IBOutlet weak var changeReadStateButton: StartFinishButton!
    
    @IBOutlet weak var readState: UILabel!
    @IBOutlet weak var dateStarted: UILabel!
    @IBOutlet weak var dateFinished: UILabel!
    @IBOutlet weak var readTime: UILabel!
    @IBOutlet weak var notes: UILabel!
    
    @IBOutlet weak var isbn: UILabel!
    @IBOutlet weak var pages: UILabel!
    @IBOutlet weak var published: UILabel!
    @IBOutlet weak var subjects: UILabel!
    
    @IBOutlet weak var listName: DynamicUILabel!
    @IBOutlet weak var addToList: DynamicUILabel!
    
    @IBOutlet weak var googleBooks: UILabel!
    @IBOutlet weak var amazon: UILabel!
    
    var didShowNavigationItemTitle = false
    var shouldTruncateLongDescriptions = true
    
    var parentSplitViewController: SplitViewController? {
        get { return appDelegate.tabBarController.selectedViewController as? SplitViewController }
    }
    
    func setViewEnabled(enabled: Bool) {
        // Show the whole view and nav bar buttons
        view.isHidden = !enabled
        navigationItem.rightBarButtonItems?.forEach({$0.toggleHidden(hidden: !enabled)})
    }
    
    var book: Book? {
        didSet { setupViewFromBook() }
    }
    
    func setupViewFromBook() {
        // Hide the whole view and nav bar buttons if there's no book
        guard let book = book else { setViewEnabled(enabled: false); return }
        setViewEnabled(enabled: true)
        
        cover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        
        // There are 2 title and 2 author labels, one for Regular display (iPad) and one for other displays
        titleAndAuthorStack.subviews[0...1].forEach{($0 as! UILabel).text = book.title}
        titleAndAuthorStack.subviews[2...3].forEach{($0 as! UILabel).text = book.authorsFirstLast}
        (navigationItem.titleView as! UINavigationBarLabel).setTitle(book.title)
        
        switch book.readState {
        case .toRead:
            changeReadStateButton.setState(.start)
        case .reading:
            changeReadStateButton.setState(.finish)
        case .finished:
            changeReadStateButton.setState(.none)
        }
        
        bookDescription.text = book.bookDescription
        bookDescription.superview!.isHidden = book.bookDescription == nil
        bookDescription.superview!.nextSibling!.isHidden = book.bookDescription == nil
        
        func setTextOrHideLine(_ label: UILabel, _ string: String?) {
            // The detail labels are arranged in the following hierachy:
            /*
             vertical-stack
                horizontal-stack
                    property label
                    property value view
                        property value label
            */
            // If a property is nil, we should hide the enclosing horizontal stack
            label.text = string
            label.superview!.superview!.isHidden = string == nil
        }
        // Read state is always present
        readState.text = book.readState.longDescription
        setTextOrHideLine(dateStarted, book.startedReading?.toPrettyString(short: false))
        setTextOrHideLine(dateFinished, book.finishedReading?.toPrettyString(short: false))
        
        let readTimeText: String?
        if book.readState == .toRead {
            readTimeText = nil
        }
        else {
            let dayCount = NSCalendar.current.dateComponents([.day], from: book.startedReading!.startOfDay(), to: (book.finishedReading ?? Date()).startOfDay()).day ?? 0
            if dayCount <= 0 && book.readState == .finished {
                readTimeText = "Within a day"
            }
            else if dayCount == 1 {
                readTimeText =  "1 day"
            }
            else {
                readTimeText = "\(dayCount) days"
            }
        }
        setTextOrHideLine(readTime, readTimeText)
        setTextOrHideLine(notes, book.notes)

        setTextOrHideLine(isbn, book.isbn13)
        setTextOrHideLine(pages, book.pageCount?.stringValue)
        setTextOrHideLine(published, book.publicationDate?.toPrettyString(short: false))
        setTextOrHideLine(subjects, book.subjectsArray.count == 0 ? nil : book.subjectsArray.map{$0.name}.joined(separator: ", "))
        
        listName.text = book.listsArray.map{$0.name}.joined(separator: ", ")
        
        googleBooks.isHidden = book.googleBooksId == nil
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
        
        // Listen for taps on the Google and Amazon labels, which should act like buttons and open the relevant webpage
        amazon.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(amazonButtonPressed)))
        googleBooks.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(googleBooksButtonPressed)))
        addToList.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(addToListPressed)))
        
        // A custom title view is required for animation
        navigationItem.titleView = UINavigationBarLabel()
        navigationItem.titleView!.isHidden = true

        // Watch for changes in the managed object context
        NotificationCenter.default.addObserver(self, selector: #selector(bookChanged(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: appDelegate.booksStore.managedObjectContext)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // If we should not be truncating long descriptions, hide the siblings of the description label (which are the see more
        // button and a spacer view)
        let truncationViews = bookDescription.siblings
        guard shouldTruncateLongDescriptions else { truncationViews.forEach{$0.isHidden = true}; return }
        
        // In "regular" size classed devices, the description text should be less truncated
        if sizeClass() == (.regular, .regular) {
            bookDescription.numberOfLines = 8
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
        
        let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet ?? NSSet()
        guard deletedObjects.contains(book) != true else {
            // If the book was deleted, set our book to nil and update this page. Pop back to the book table if necessary
            self.book = nil
            parentSplitViewController?.masterNavigationController.popToRootViewController(animated: false)
            return
        }
        
        let updatedObjects = userInfo[NSUpdatedObjectsKey] as? NSSet ?? NSSet()
        let createdObjects = userInfo[NSInsertedObjectsKey] as? NSSet ?? NSSet()
        func setContainsRelatedList(_ set: NSSet) -> Bool {
           return set.flatMap({$0 as? List}).any(where: {$0.booksArray.contains(book)})
        }
        
        if updatedObjects.contains(book) || setContainsRelatedList(deletedObjects) || setContainsRelatedList(updatedObjects) || setContainsRelatedList(createdObjects) {
            // If the book was updated, update this page.
            setupViewFromBook()
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
    
    @objc func amazonButtonPressed() {
        guard let book = book else { return }
        let amazonUrl = "https://www.amazon.com/s?url=search-alias%3Dstripbooks&field-author=\(book.authorsArray.first?.displayFirstLast ?? "")&field-title=\(book.title)"
        
        // Use https://bestazon.io/#WebService to localize Amazon links
        let azonUrl = "http://lnks.io/r.php?Conf_Source=API&destURL=\(amazonUrl.urlEncoded())&Amzn_AfiliateID_GB=readinglistap-21"
        UIApplication.shared.openURL(URL(string: azonUrl)!)
    }
    
    @objc func googleBooksButtonPressed() {
        guard let googleBooksId = book?.googleBooksId else { return }
        UIApplication.shared.openURL(GoogleBooks.Request.webpage(googleBooksId).url)
    }
    
    @objc func addToListPressed() {
        guard let book = book else { return }
        present(AddToList.getAppropriateViewController(booksToAdd: [book]), animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // 18 is the padding between the main stack view and the top. This should be determined programatically
        // if any of the layout constraints from the title to the top become more complex
        let threshold = titleAndAuthorStack.subviews.first(where: {!$0.isHidden})!.frame.maxY + 18 - scrollView.universalContentInset.top

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
