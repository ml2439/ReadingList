import Foundation
import UIKit
import CoreData

class BookDetails: UIViewController, UIScrollViewDelegate {
    @IBOutlet private weak var cover: UIImageView!
    @IBOutlet private weak var changeReadStateButton: StartFinishButton!

    @IBOutlet private var titles: [UILabel]!

    @IBOutlet private var titleAuthorHeadings: [UILabel]!
    @IBOutlet private weak var bookDescription: UILabel!

    @IBOutlet private var tableVaules: [UILabel]!
    @IBOutlet private var tableSubHeadings: [UILabel]!

    @IBOutlet private weak var googleBooks: UILabel!
    @IBOutlet private weak var amazon: UILabel!

    @IBOutlet private var separatorLines: [UIView]!
    @IBOutlet private weak var listsStack: UIStackView!
    @IBOutlet private weak var listDetailsView: UIView!
    @IBOutlet private weak var noLists: UILabel!

    var didShowNavigationItemTitle = false
    var shouldTruncateLongDescriptions = true

    var parentSplitViewController: UISplitViewController? {
        return appDelegate.tabBarController.selectedSplitViewController
    }

    func setViewEnabled(_ enabled: Bool) {
        // Show the whole view and nav bar buttons
        view.isHidden = !enabled
        navigationItem.rightBarButtonItems?.forEach { $0.setHidden(!enabled) }
    }

    var book: Book? {
        didSet { setupViewFromBook() }
    }

    func setupViewFromBook() { //swiftlint:disable:this cyclomatic_complexity
        // Hide the whole view and nav bar buttons if there's no book
        guard let book = book else { setViewEnabled(false); return }
        setViewEnabled(true)

        cover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        titleAuthorHeadings[0].text = book.title
        titleAuthorHeadings[1].text = book.authorDisplay
        if traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular {
            titleAuthorHeadings.forEach { $0.scaleFontBy(1.3) }
        }
        (navigationItem.titleView as! UINavigationBarLabel).setTitle(book.title)

        switch book.readState {
        case .toRead:
            changeReadStateButton.setState(.start)
        case .reading:
            // It is not "invalid" to have a book with a started date in the future; but it is invalid
            // to have a finish date before the start date. Therefore, hide the finish button if
            // this would be the case.
            changeReadStateButton.setState(book.startedReading! < Date() ? .finish : .none)
        case .finished:
            changeReadStateButton.setState(.none)
        }

        bookDescription.text = book.bookDescription
        bookDescription.superview!.isHidden = book.bookDescription == nil
        bookDescription.superview!.nextSibling!.isHidden = book.bookDescription == nil

        func setTextOrHideLine(_ label: UILabel, _ string: String?) {
            // The detail labels are within a view, within a horizonal-stack
            // If a property is nil, we should hide the enclosing horizontal stack
            label.text = string
            label.superview!.superview!.isHidden = string == nil
        }

        // Read state is always present
        tableVaules[0].text = book.readState.longDescription
        setTextOrHideLine(tableVaules[1], book.startedReading?.toPrettyString(short: false))
        setTextOrHideLine(tableVaules[2], book.finishedReading?.toPrettyString(short: false))

        let readTimeText: String?
        if book.readState == .toRead {
            readTimeText = nil
        } else {
            let dayCount = NSCalendar.current.dateComponents([.day], from: book.startedReading!.startOfDay(), to: (book.finishedReading ?? Date()).startOfDay()).day ?? 0
            if dayCount <= 0 && book.readState == .finished {
                readTimeText = "Within a day"
            } else if dayCount == 1 {
                readTimeText =  "1 day"
            } else {
                readTimeText = "\(dayCount) days"
            }
        }
        setTextOrHideLine(tableVaules[3], readTimeText)
        let pageNumberText: String?
        if let currentPage = book.currentPage?.intValue {
            if let totalPages = book.pageCount?.intValue, currentPage <= totalPages, currentPage > 0 {
                pageNumberText = "\(currentPage) (\(100 * currentPage / totalPages)% complete)"
            } else {
                pageNumberText = currentPage.string
            }
        } else { pageNumberText = nil }

        setTextOrHideLine(tableVaules[4], pageNumberText)
        setTextOrHideLine(tableVaules[5], book.notes)
        setTextOrHideLine(tableVaules[6], book.isbn13)
        setTextOrHideLine(tableVaules[7], book.pageCount?.intValue.string)
        setTextOrHideLine(tableVaules[8], book.publicationDate?.toPrettyString(short: false))
        setTextOrHideLine(tableVaules[9], book.subjects.map { $0.name }.sorted().joined(separator: ", ").nilIfWhitespace())

        // Show or hide the links, depending on whether we have valid URLs. If both links are hidden, the enclosing stack should be too.
        googleBooks.isHidden = book.googleBooksId == nil
        amazon.isHidden = book.amazonAffiliateLink == nil
        amazon.superview!.superview!.isHidden = googleBooks.isHidden && amazon.isHidden

        // Remove all the existing list labels, then add a label per list. Copy the list properties from another similar label, that's easier
        listsStack.removeAllSubviews()
        for list in book.lists {
            listsStack.addArrangedSubview(UILabel(font: tableVaules[0].font, color: tableVaules[0].textColor, text: list.name))
        }

        // There is a placeholder view for the case of no lists. Lists are stored in 3 nested stack views
        noLists.isHidden = !book.lists.isEmpty
        listsStack.superview!.superview!.superview!.isHidden = book.lists.isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialise the view so that by default a blank page is shown.
        // This is required for starting the app in split-screen mode, where this view is
        // shown without any books being selected.
        setViewEnabled(false)

        // Listen for taps on the book description, which should remove any truncation
        bookDescription.superview!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(seeMoreDescription)))

        // Listen for taps on the Google and Amazon labels, which should act like buttons and open the relevant webpage
        amazon.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(amazonButtonPressed)))
        googleBooks.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(googleBooksButtonPressed)))

        // A custom title view is required for animation
        navigationItem.titleView = UINavigationBarLabel()
        navigationItem.titleView!.isHidden = true

        // Watch for changes in the managed object context
        NotificationCenter.default.addObserver(self, selector: #selector(saveOccurred(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: PersistentStoreManager.container.viewContext)

        monitorThemeSetting()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // If we should not be truncating long descriptions, hide the siblings of the description label (which are the see more
        // button and a spacer view)
        let truncationViews = bookDescription.siblings
        guard shouldTruncateLongDescriptions else { truncationViews.forEach { $0.isHidden = true }; return }

        // In "regular" size classed devices, the description text can be less truncated
        if traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular {
            bookDescription.numberOfLines = 8
        }

        if truncationViews.first!.isHidden == bookDescription.isTruncated {
            truncationViews.forEach { $0.isHidden = !bookDescription.isTruncated }
        }
    }

    @IBAction private func updateReadingLogPressed(_ sender: Any) {
        present(EditBookReadState(existingBookID: book!.objectID).inThemedNavController(), animated: true)
    }

    @IBAction private func editBookPressed(_ sender: Any) {
        present(EditBookMetadata(bookToEditID: book!.objectID).inThemedNavController(), animated: true)
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

    @objc func saveOccurred(_ notification: Notification) {
        guard let book = book, let userInfo = (notification as NSNotification).userInfo else { return }

        let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet ?? NSSet()
        guard deletedObjects.contains(book) != true else {
            // If the book was deleted, set our book to nil and update this page. Pop back to the book table if necessary
            self.book = nil
            parentSplitViewController?.masterNavigationController.popToRootViewController(animated: false)
            return
        }

        // FUTURE: Consider whether it is worth inspecting the changes to see if they affect this book; perhaps we should just always reload?

        let updatedObjects = userInfo[NSUpdatedObjectsKey] as? NSSet ?? NSSet()
        let createdObjects = userInfo[NSInsertedObjectsKey] as? NSSet ?? NSSet()
        func setContainsRelatedList(_ set: NSSet) -> Bool {
            return set.compactMap { $0 as? List }.any { $0.books.contains(book) }
        }

        if updatedObjects.contains(book) || setContainsRelatedList(deletedObjects) || setContainsRelatedList(updatedObjects) || setContainsRelatedList(createdObjects) {
            // If the book was updated, update this page.
            setupViewFromBook()
        }
    }

    @IBAction private func changeReadStateButtonWasPressed(_ sender: BorderedButton) {
        guard let book = book, book.readState == .toRead || book.readState == .reading else { return }

        if book.readState == .toRead {
            book.startReading()
        } else {
            book.finishReading()
        }
        book.managedObjectContext!.saveAndLogIfErrored()

        UserEngagement.logEvent(.transitionReadState)
        UserEngagement.onReviewTrigger()
    }

    @objc func amazonButtonPressed() {
        guard let book = book, let amazonLink = book.amazonAffiliateLink else { return }
        UserEngagement.logEvent(.viewOnAmazon)
        presentThemedSafariViewController(amazonLink)
    }

    @objc func googleBooksButtonPressed() {
        guard let googleBooksId = book?.googleBooksId else { return }
        presentThemedSafariViewController(GoogleBooks.Request.webpage(googleBooksId).url)
    }

    @IBAction private func addToList(_ sender: Any) {
        guard let book = book else { return }
        present(AddToList.getAppropriateVcForAddingBooksToList([book]) {
            UserEngagement.logEvent(.addBookToList)
            UserEngagement.onReviewTrigger()
        }, animated: true)
    }

    @IBAction private func shareButtonPressed(_ sender: UIBarButtonItem) {
        guard let book = book else { return }

        let activityViewController = UIActivityViewController(activityItems: ["\(book.title)\n\(book.authorDisplay)"], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = sender

        var excludedActivityTypes: [UIActivityType] = [.assignToContact, .saveToCameraRoll, .addToReadingList, .postToFlickr, .postToVimeo, .openInIBooks]
        if #available(iOS 11.0, *) {
            excludedActivityTypes.append(.markupAsPDF)
        }
        activityViewController.excludedActivityTypes = excludedActivityTypes

        present(activityViewController, animated: true, completion: nil)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let titleLabel = titleAuthorHeadings[0]
        let titleMaxYPosition = titleLabel.convert(titleLabel.frame, to: view).maxY
        if didShowNavigationItemTitle != (titleMaxYPosition - scrollView.universalContentInset.top < 0) {
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
        guard let book = book else { return [UIPreviewActionItem]() }

        var previewActions = [UIPreviewActionItem]()
        if book.readState == .toRead {
            previewActions.append(UIPreviewAction(title: "Start", style: .default) { _, _ in
                book.startReading()
                book.managedObjectContext!.saveAndLogIfErrored()
                UserEngagement.logEvent(.transitionReadState)
            })
        } else if book.readState == .reading {
            previewActions.append(UIPreviewAction(title: "Finish", style: .default) { _, _ in
                book.finishReading()
                book.managedObjectContext!.saveAndLogIfErrored()
                UserEngagement.logEvent(.transitionReadState)
            })
        }
        previewActions.append(UIPreviewAction(title: "Delete", style: .destructive) { _, _ in
            book.deleteAndSave()
            UserEngagement.logEvent(.deleteBook)
        })
        return previewActions
    }
}

extension BookDetails: ThemeableViewController {
    func initialise(withTheme theme: Theme) {
        view.backgroundColor = theme.viewBackgroundColor
        navigationController?.view.backgroundColor = theme.viewBackgroundColor
        navigationController?.navigationBar.initialise(withTheme: theme)
        (navigationItem.titleView as! UINavigationBarLabel).initialise(fromTheme: theme)
        titleAuthorHeadings[0].textColor = theme.titleTextColor
        titleAuthorHeadings[1].textColor = theme.subtitleTextColor

        bookDescription.textColor = theme.subtitleTextColor
        bookDescription.siblings.compactMap { $0 as? HorizontalGradientView }.first!.color = theme.viewBackgroundColor

        titles.forEach { $0.textColor = theme.titleTextColor }
        tableSubHeadings.forEach { $0.textColor = theme.subtitleTextColor }
        tableVaules.forEach { $0.textColor = theme.titleTextColor }
        separatorLines.forEach { $0.backgroundColor = theme.cellSeparatorColor }
        listsStack.arrangedSubviews.forEach { ($0 as! UILabel).textColor = theme.titleTextColor }
    }
}

extension Book {
    var amazonAffiliateLink: URL? {
        let authorText = (authors.firstObject as? Author)?.displayFirstLast
        let amazonSearch = "https://www.amazon.com/s?url=search-alias%3Dstripbooks&field-author=\(authorText ?? "")&field-title=\(title)"

        // Use https://bestazon.io/#WebService to localize Amazon links
        // US store: readinglistio-20; UK store: readinglistio-21
        let refURL = "https://www.readinglistapp.xyz"
        return URL(string: "http://lnks.io/r.php?Conf_Source=API&refURL=\(refURL.urlEncoding())&destURL=\(amazonSearch.urlEncoding())&Amzn_AfiliateID_GB=readinglistio-21&Amzn_AfiliateID_US=readinglistio-20")
    }
}
