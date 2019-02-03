import Foundation
import Eureka
import UIKit
import CoreData

class EditBookReadState: FormViewController {

    private var editContext: NSManagedObjectContext!
    private var book: Book!
    private var newBook = false
    private let currentPageKey = "currentPage"

    convenience init(existingBookID: NSManagedObjectID) {
        self.init()
        self.editContext = PersistentStoreManager.container.viewContext.childContext()
        self.book = (editContext.object(with: existingBookID) as! Book)
    }

    convenience init(newUnsavedBook: Book, scratchpadContext: NSManagedObjectContext) {
        self.init()
        self.newBook = true
        self.book = newUnsavedBook
        self.editContext = scratchpadContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationItem()

        // Watch the book object for changes and validate the form
        NotificationCenter.default.addObserver(self, selector: #selector(validate), name: .NSManagedObjectContextObjectsDidChange, object: editContext)

        let now = Date()

        let readStateKey = "readState"
        let startedReadingKey = "startedReading"
        let finishedReadingKey = "finishedReading"

        form +++ Section(header: "Reading Log", footer: "")
            <<< SegmentedRow<BookReadState>(readStateKey) {
                $0.options = [.toRead, .reading, .finished]
                $0.value = book.readState
                $0.onChange { [unowned self] row in
                    self.book.readState = row.value!

                    // Make sure we update the read dates
                    switch self.book.readState {
                    case .toRead:
                        self.book.startedReading = nil
                        self.book.finishedReading = nil
                        self.book.currentPage = nil
                    case .reading:
                        self.book.startedReading = (self.form.rowBy(tag: startedReadingKey) as! DateRow).value
                        self.book.finishedReading = nil
                        if let currentPage = (self.form.rowBy(tag: self.currentPageKey) as! IntRow).value, currentPage >= 0 && currentPage <= Int32.max {
                            self.book.currentPage = currentPage.nsNumber
                        } else { self.book.currentPage = nil }
                    case .finished:
                        self.book.startedReading = (self.form.rowBy(tag: startedReadingKey) as! DateRow).value
                        self.book.finishedReading = (self.form.rowBy(tag: finishedReadingKey) as! DateRow).value
                        self.book.currentPage = nil
                    }
                }
            }
            <<< DateRow(startedReadingKey) {
                $0.title = "Started"
                //$0.maximumDate = Date.startOfToday()
                $0.value = book.startedReading ?? now
                $0.onChange { [unowned self] cell in
                    self.book.startedReading = cell.value
                }
                $0.hidden = Condition.function([readStateKey]) { [unowned self] _ in
                    self.book.readState == .toRead
                }
            }
            <<< DateRow(finishedReadingKey) {
                $0.title = "Finished"
                //$0.maximumDate = Date.startOfToday()
                $0.hidden = Condition.function([readStateKey]) { [unowned self] _ in
                    self.book.readState != .finished
                }
                $0.value = book.finishedReading ?? now
                $0.onChange {[unowned self] cell in
                    self.book.finishedReading = cell.value
                }
            }
            <<< IntRow(currentPageKey) {
                $0.title = "Current Page"
                $0.value = book.currentPage?.intValue
                $0.hidden = Condition.function([readStateKey]) { [unowned self] _ in
                    self.book.readState != .reading
                }
                $0.onChange { [unowned self] cell in
                    self.book.currentPage = cell.value?.nsNumber
                }
            }

        monitorThemeSetting()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // If we are editing a book (not adding one), pre-select the current page field
        if self.book.readState == .reading && self.book.changedValues().isEmpty {
            let currentPageRow = self.form.rowBy(tag: currentPageKey) as! IntRow
            currentPageRow.cell.textField.becomeFirstResponder()
        }
    }

    func configureNavigationItem() {
        if navigationItem.leftBarButtonItem == nil && navigationController!.viewControllers.first == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPressed))
        }
        navigationItem.title = book.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
    }

    @objc func validate() {
        navigationItem.rightBarButtonItem!.isEnabled = book.isValidForUpdate()
    }

    @objc func cancelPressed() {
        // FUTURE: Duplicates code in EditBookMetadata. Consolidate.
        guard book.changedValues().isEmpty else {
            // Confirm exit dialog
            let confirmExit = UIAlertController(title: "Unsaved changes", message: "Are you sure you want to discard your unsaved changes?", preferredStyle: .actionSheet)
            confirmExit.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
                self.dismiss(animated: true)
            })
            confirmExit.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(confirmExit, animated: true, completion: nil)
            return
        }

        dismiss(animated: true, completion: nil)
    }

    @objc func donePressed() {
        guard book.isValidForUpdate() else { return }

        view.endEditing(true)
        editContext.saveIfChanged()

        // FUTURE: Figure out a better way to solve this problem.
        // If the previous view controller was the SearchOnline VC, then we need to deactivate its search controller
        // so that it doesn't end up being leaked. We can't do that on viewWillDissappear, since that would clear the
        // search bar, which is annoying if the user navigates back to that view.
        if let searchOnline = navigationController!.viewControllers.first as? SearchOnline {
            searchOnline.searchController.isActive = false
        }

        presentingViewController!.dismiss(animated: true) {
            if self.newBook {
                (self.tabBarController as? TabBarController)?.simulateBookSelection(self.book, allowTableObscuring: false)
            }
            UserEngagement.onReviewTrigger()
        }
    }
}
