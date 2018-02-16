import Foundation
import Eureka
import ImageRow
import UIKit
import CoreData
import SVProgressHUD

class EditBookMetadata: FormViewController {

    var bookToEditID: NSManagedObjectID?
    private var editBookContext: NSManagedObjectContext!
    private var book: Book!
    private var isAddingNewBook: Bool {
        get { return bookToEditID == nil }
    }

    convenience init(_ bookToEditID: NSManagedObjectID?) {
        self.init()
        self.bookToEditID = bookToEditID
    }
    
    func getOrCreateBook() -> Book {
        // Create a child context and either find the existing book or insert a new one
        editBookContext = container.viewContext.childContext()
        if let bookToEditId = bookToEditID {
            book = editBookContext.object(with: bookToEditId) as! Book
        }
        else {
            book = Book(context: editBookContext, readState: .reading)
        }
        
        // Watch the book object for changes and validate the form
        NotificationCenter.default.addObserver(self, selector: #selector(validate), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: editBookContext)

        return book
    }
    
    let isbnRowKey = "isbn"
    let deleteRowKey = "delete"
    let updateFromGoogleRowKey = "updateFromGoogle"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationItem()
        
        let book = getOrCreateBook()

        form +++ Section(header: "Title", footer: "")
            <<< NameRow() {
                $0.placeholder = "Title"
                $0.value = book.title
                $0.onChange{book.title = $0.value ?? ""}
            }
            
            +++ AuthorSection(book: book, navigationController: navigationController!)
            
            // ****************************************************************** //
            // *****************     ADDITIONAL INFORMATION      **************** //
            // ****************************************************************** //
            +++ Section(header: "Additional Information", footer: "")
            <<< TextRow(isbnRowKey) {
                $0.title = "ISBN"
                $0.value = book.isbn13
                $0.disabled = Condition(booleanLiteral: true)
            }
            <<< IntRow() {
                $0.title = "Page Count"
                $0.value = book.pageCount
                $0.onChange{book.pageCount = $0.value}
            }
            <<< DateRow() {
                $0.title = "Publication Date"
                $0.value = book.publicationDate
                $0.onChange{book.publicationDate = $0.value}
            }
            <<< ButtonRow() { row in
                row.title = "Subjects"
                row.cellStyle = .value1
                row.cellUpdate{cell,_ in
                    cell.textLabel!.textAlignment = .left
                    cell.textLabel!.textColor = .black
                    cell.accessoryType = .disclosureIndicator
                    cell.detailTextLabel?.text = self.book.subjects.map{($0 as! Subject).name}.joined(separator: ", ")
                }
                row.onCellSelection{ [unowned self] _,_ in
                    self.navigationController!.pushViewController(EditBookSubjectsForm(book: book, sender: row), animated: true)
                }
            }
            <<< ImageRow() {
                $0.title = "Cover Image"
                $0.cell.height = {return 100}
                $0.value = UIImage(optionalData: book.coverImage)
                $0.onChange{book.coverImage = $0.value == nil ? nil : UIImageJPEGRepresentation($0.value!, 0.7)}
            }

            +++ Section(header: "Description", footer: "")
            <<< TextAreaRow() {
                $0.placeholder = "Description"
                $0.value = book.bookDescription
                $0.onChange{book.bookDescription = $0.value}
                $0.cellSetup{ [unowned self] cell, _ in
                    cell.height = {return (self.view.frame.height / 3) - 10}
                }
            }
            
            // Update and delete buttons
            +++ Section()
            <<< ButtonRow(updateFromGoogleRowKey){
                $0.title = "Update from Google Books"
                $0.onCellSelection(updateFromGooglePressed(cell:row:))
            }
            <<< ButtonRow(deleteRowKey){
                $0.title = "Delete"
                $0.cellSetup{cell, _ in cell.tintColor = UIColor.red}
                $0.onCellSelection(deletePressed(cell:row:))
                $0.hidden = Condition(booleanLiteral: isAddingNewBook)
            }
        
        // Don't often show the isbn row
        form.rowBy(tag: isbnRowKey)!.hidden = Condition(booleanLiteral: isAddingNewBook || book.isbn13 == nil)
        form.rowBy(tag: updateFromGoogleRowKey)!.hidden = Condition(booleanLiteral: isAddingNewBook)
        //form.rows.forEach{$0.evaluateHidden()}
    }
    
    func configureNavigationItem() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPressed))
        if isAddingNewBook {
            navigationItem.title = "Add Book"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(presentEditReadingState))
        }
        else {
            navigationItem.title = "Edit Book"
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        }
    }
    
    func deletePressed(cell: ButtonCellOf<String>, row: ButtonRow) {
        guard !isAddingNewBook else { return }
        
        let confirmDeleteAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) {[unowned self] _ in
            // Dismiss this modal view, delete the book, and log the event
            self.dismiss(animated: true) {
                self.book.managedObjectContext!.performAndSave {
                    self.book.delete()
                }
                UserEngagement.logEvent(.deleteBook)
            }
        })

        self.present(confirmDeleteAlert, animated: true, completion: nil)
    }
    
    func updateFromGooglePressed(cell: ButtonCellOf<String>, row: ButtonRow) {
        let areYouSure = UIAlertController(title: "Confirm Update", message: "Updating from Google Books will overwrite any book metadata changes you have made manually. Are you sure you wish to proceed?", preferredStyle: .alert)
        areYouSure.addAction(UIAlertAction(title: "Update", style: .default){[unowned self] _ in self.updateBookFromGoogle()})
        areYouSure.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(areYouSure, animated: true)
    }

    func updateBookFromGoogle() {
        guard let googleBooksId = book.googleBooksId else { return }

        SVProgressHUD.show(withStatus: "Downloading...")
        GoogleBooks.fetch(googleBooksId: googleBooksId) { [unowned self] fetchResultPage in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                guard fetchResultPage.result.isSuccess else {
                    SVProgressHUD.showError(withStatus: "Could not update book details")
                    return
                }
                self.book.populate(fromFetchResult: fetchResultPage.result.value!)
                self.dismiss(animated: true) {
                    SVProgressHUD.showInfo(withStatus: "Book updated")
                }
            }
        }
    }
    
    @objc func validate() {
        navigationItem.rightBarButtonItem!.isEnabled = book.isValidForUpdate()
    }
    
    @objc func cancelPressed() {
        guard book.changedValues().count == 0 else {
            // Confirm exit dialog
            let confirmExit = UIAlertController(title: "Unsaved changes", message: "Are you sure you want to discard your unsaved changes?", preferredStyle: .actionSheet)
            confirmExit.addAction(UIAlertAction(title: "Discard", style: .destructive){ [unowned self] _ in
                self.dismiss(animated: true)
            })
            confirmExit.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(confirmExit, animated: true, completion: nil)
            return
        }

        dismiss(animated: true, completion: nil)
    }
    
    @objc func donePressed() {
        if editBookContext.trySaveIfChanged() {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func presentEditReadingState() {
        navigationController!.pushViewController(EditBookReadState(newUnsavedBook: book), animated: true)
    }
    
}

class AuthorSection: MultivaluedSection {
    var book: Book!
    weak var navigationController: UINavigationController!
    
    required init(book: Book, navigationController: UINavigationController) {
        super.init(multivaluedOptions: [.Insert, .Delete], header: "Authors", footer: "") {
            for author in book.authors.flatMap({$0 as? Author}) {
                $0 <<< AuthorRow(author: author, navigationController: navigationController)
            }
            
            $0.addButtonProvider = { _ in
                return ButtonRow() {
                    $0.title = "Add Author"
                    $0.cellUpdate{ cell,_ in cell.textLabel!.textAlignment = .left }
                }
            }
            
            $0.multivaluedRowToInsertAt = { _ in
                let newAuthor = Author(context: book.managedObjectContext!)
                book.addAuthors(NSOrderedSet(array: [newAuthor]))
                let authorRow = AuthorRow(author: newAuthor, navigationController: navigationController)
                authorRow.pushEditAuthorView()
                return authorRow
            }
        }
        self.book = book
        self.navigationController = navigationController
    }
    
    required init() {
        super.init(multivaluedOptions: [.Insert, .Delete], header: "Authors", footer: "", {_ in})
    }
    
    required init(multivaluedOptions: MultivaluedOptions, header: String, footer: String, _ initializer: (MultivaluedSection) -> Void) {
        super.init(multivaluedOptions: multivaluedOptions, header: header, footer: footer, initializer)
    }
    
    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at: IndexSet) {
        super.rowsHaveBeenRemoved(rows, at: at)
        rows.map{($0 as! AuthorRow).author}.forEach{$0?.delete()}
    }
}

final class AuthorRow: _ButtonRowOf<String>, RowType {
    var author: Author!
    weak var navigationController: UINavigationController!
    
    convenience init(author: Author, navigationController: UINavigationController) {
        self.init()
        self.author = author
        self.navigationController = navigationController
    }
    
    required init(tag: String?) {
        super.init(tag: tag)
        cellStyle = .value1

        cellUpdate{ [unowned self] cell,row in
            cell.textLabel!.textColor = UIColor.black
            cell.textLabel!.textAlignment = .left
            cell.textLabel!.text = self.author.displayFirstLast
        }
        
        onCellSelection{ [unowned self] _,_ in
            self.pushEditAuthorView()
        }
    }
    
    func pushEditAuthorView() {
        self.navigationController.pushViewController(EditAuthorMetadata(self), animated: true)
    }
}

class EditAuthorMetadata: FormViewController {

    weak var row: AuthorRow!
    
    convenience init(_ row: AuthorRow) {
        self.init()
        self.row = row
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        form +++ Section(header: "Author Name", footer: "")
            <<< NameRow() {
                $0.placeholder = "First Name(s)"
                $0.value = row.author.firstNames
                $0.onChange{[unowned self] in self.row.author.firstNames = $0.value}
            }
            <<< NameRow() {
                $0.placeholder = "Last Name"
                $0.value = row.author.lastName
                $0.onChange{[unowned self] in self.row.author.lastName = $0.value ?? ""}
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if row.author.isValidForUpdate() {
            row.reload()
        }
        else {
            row.removeSelf()
        }
    }
}


class EditBookSubjectsForm: FormViewController {

    convenience init(book: Book, sender: ButtonRow) {
        self.init()
        self.book = book
        self.sendingRow = sender
    }
    
    var book: Book!
    weak var sendingRow: ButtonRow!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        form +++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete, .Reorder], header: "Subjects", footer: "Add subjects to categorise this book") {
            $0.addButtonProvider = { _ in
                return ButtonRow(){
                    $0.title = "Add New Subject"
                    $0.cellUpdate{ cell,row in
                        cell.textLabel?.textAlignment = .left
                    }
                }
            }
            $0.multivaluedRowToInsertAt = { _ in
                return NameRow() {
                    $0.placeholder = "Subject"
                }
            }
            for subject in book.subjects {
                $0 <<< NameRow() {
                    $0.value = (subject as! Subject).name
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // TODO: Match the Author behaviour and add Subjects each time Add is pressed
        let subjectNames = form.rows.flatMap{($0 as? NameRow)?.value?.trimming().nilIfWhitespace()}
        if book.subjects.map({($0 as! Subject).name}) != subjectNames {
            book.subjects = NSOrderedSet(array: subjectNames.map{Subject.getOrCreate(inContext: book.managedObjectContext!, withName: $0)})
        }
        sendingRow.reload()
    }
}
