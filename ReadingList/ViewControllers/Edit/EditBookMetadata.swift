import Foundation
import Eureka
import ImageRow
import UIKit
import CoreData

class EditBookMetadata: FormViewController {

    var bookToEditID: NSManagedObjectID?
    
    private var editBookContext: NSManagedObjectContext!
    private var book: Book!
    private var mode: Mode!
    
    enum Mode {
        case create
        case edit
    }
    
    static func inNavigationController(bookToEditId: NSManagedObjectID? = nil) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: EditBookMetadata(bookToEditId))
        navigationController.modalPresentationStyle = .formSheet
        return navigationController
    }
    
    convenience init(_ bookToEditID: NSManagedObjectID?) {
        self.init()
        self.bookToEditID = bookToEditID
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print(book.authors.count)
    }
    
    func getOrCreateBook() -> Book {
        // Create a child context and either find the existing book or insert a new one
        editBookContext = container.viewContext.childContext()
        if let bookToEditId = bookToEditID {
            book = editBookContext.object(with: bookToEditId) as! Book
        }
        else {
            book = Book(context: editBookContext)
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
        
        mode = bookToEditID == nil ? .create : .edit
        configureNavigationItem()
        
        let book = getOrCreateBook()

        form +++ Section(header: "Title", footer: "")
            <<< NameRow() {
                $0.placeholder = "Title"
                $0.value = book.title
                $0.onChange{book.title = $0.value ?? ""}
            }
            
            +++ AuthorSection(book: book, navigationController: navigationController!)
            
            +++ Section(header: "Additional Information", footer: "")
            <<< TextRow(isbnRowKey) {
                $0.title = "ISBN"
                $0.value = book.isbn13
                $0.disabled = Condition(booleanLiteral: true)
            }
            <<< IntRow() {
                $0.title = "Page Count"
                $0.value = book.pageCount?.intValue
                $0.onChange{book.pageCount = $0.value == nil ? nil : NSNumber(integerLiteral: $0.value!)}
            }
            <<< DateRow() {
                $0.title = "Publication Date"
                $0.value = book.publicationDate
                $0.onChange{book.publicationDate = $0.value}
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
            }
        
        if mode == .create || book.isbn13 == nil {
            // Don't often show the isbn row
            form.rowBy(tag: isbnRowKey)!.hidden = Condition(booleanLiteral: true)
        }
        if mode == .create {
            form.rowBy(tag: updateFromGoogleRowKey)!.hidden = Condition(booleanLiteral: true)
            form.rowBy(tag: deleteRowKey)!.hidden = Condition(booleanLiteral: true)
        }
    }
    
    func configureNavigationItem() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPressed))
        if mode == .create {
            navigationItem.title = "Add Book"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(presentEditReadingState))
        }
        else {
            navigationItem.title = "Edit Book"
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        }
    }
    
    func deletePressed(cell: ButtonCellOf<String>, row: ButtonRow) {
        
    }
    
    func updateFromGooglePressed(cell: ButtonCellOf<String>, row: ButtonRow) {
        
    }
    
    @objc func validate() {
        navigationItem.rightBarButtonItem!.isEnabled = book.isValidForUpdate()
    }
    
    @objc func cancelPressed() {
        guard !editBookContext.hasChanges else {
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
        // TODO
    }
            
            /*
            // Authors
            +++ AuthorMultivaluedSection(multivaluedOptions: [.Insert, .Delete], header: "Authors", footer: "") {
                let authorSection = $0 as! AuthorMultivaluedSection
                authorSection.tag = authorsSectionKey
                $0.addButtonProvider = { _ in
                    return ButtonRow(){
                        $0.title = "Add Author"
                        }.cellUpdate { cell, row in
                            cell.textLabel?.textAlignment = .left
                    }
                }
                $0.multivaluedRowToInsertAt = { _ in
                    return AuthorButtonRow(){
                        $0.cellStyle = .value1
                        }.onCellSelection{ [unowned self] _, row in
                            self.performSegue(withIdentifier: self.editAuthorSegueName, sender: row)
                        }.cellUpdate{ cell, _ in
                            cell.textLabel?.textColor = UIColor.black
                            cell.textLabel?.textAlignment = .left
                    }
                }
                for authorValue in authors {
                    $0 <<< AuthorButtonRow() {
                        $0.cellStyle = .value1
                        $0.authorLastName = authorValue.lastName
                        $0.authorFirstNames = authorValue.firstNames
                        }.onCellSelection{ [unowned self] _, row in
                            self.performSegue(withIdentifier: self.editAuthorSegueName, sender: row)
                        }
                        .cellUpdate{ cell, _ in
                            cell.textLabel?.textColor = UIColor.black
                            cell.textLabel?.textAlignment = .left
                    }
                }
            }
     
        
        // Add callbacks after form loaded
        authorsSection.onRowsAdded = { [unowned self] rows, _ in
            guard rows.count == 1 else { return }
            if let row = rows.first! as? AuthorButtonRow {
                self.performSegue(withIdentifier: self.editAuthorSegueName, sender: row)
            }
            self.validationChanged()
        }
        authorsSection.onRowsRemoved = { [unowned self] _, _ in
            self.configureAuthorArrayFromCells()
            self.validationChanged()
        }*/
    
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
