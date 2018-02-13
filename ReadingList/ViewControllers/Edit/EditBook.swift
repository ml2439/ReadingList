import UIKit
import SVProgressHUD
import Eureka
import CoreData

class EditBook: BookMetadataForm {
    var bookToEdit: Book!
    var initialMetadata: BookMetadata!
    var initialCoverImageDataHash: MD5?
    var scratchpadContext: NSManagedObjectContext!
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        scratchpadContext = bookToEdit.managedObjectContext!.childContext()
        bookToEdit = scratchpadContext.object(with: bookToEdit.objectID) as! Book
        
        authors = bookToEdit.authors.map{
            let author = $0 as! Author
            return (author.firstNames, author.lastName)
        }
        subjects = bookToEdit.subjects.array.map{($0 as! Subject).name}
        
        super.viewDidLoad()
        
        // Disable the ISBN field (disallow editing of the ISBN), and wire up the delete button
        isbnField.disabled = true
        isbnField.evaluateDisabled()
        
        if bookToEdit.googleBooksId == nil {
            updateRow.section!.remove(at: updateRow.indexPath!.row)
        }
        else {
            updateRow.onCellSelection { [unowned self] _,_ in
                self.presentUpdateAlert()
            }
        }
        
        deleteRow.onCellSelection{ [unowned self] _,_ in
            self.presentDeleteAlert()
        }
        
        // Initialise the form with the book values
        initialMetadata = BookMetadata(book: bookToEdit)
        isbnField.value = initialMetadata.isbn13
        if initialMetadata.isbn13 == nil {
            isbnField.section!.remove(at: isbnField.indexPath!.row)
        }
        titleField.value = initialMetadata.title
        pageCount.value = initialMetadata.pageCount
        publicationDate.value = initialMetadata.publicationDate
        descriptionField.value = initialMetadata.bookDescription
        image.value = UIImage(optionalData: initialMetadata.coverImage)
        initialCoverImageDataHash = image.value == nil ? nil : MD5(data: UIImagePNGRepresentation(image.value!)!)
    }
    
    func metadataChanges() -> Bool {
        // Load the book metadata into an object from the form values
        let metadata = BookMetadata(book: bookToEdit)
        populateMetadata(metadata)

        bookToEdit.title = metadata.title!
        bookToEdit.isbn13 = metadata.isbn13
        bookToEdit.googleBooksId = metadata.googleBooksId
        bookToEdit.pageCount = metadata.pageCount as NSNumber?
        bookToEdit.publicationDate = metadata.publicationDate
        bookToEdit.bookDescription = metadata.bookDescription
        bookToEdit.coverImage = metadata.coverImage
        
        return bookToEdit.hasChanges
        /*
        
        // Update the book
        appDelegate.booksStore.populateBook(bookToEdit, withMetadata: newMetadata)
        
        if initialMetadata.title != titleField.value || initialMetadata.pageCount != pageCount.value
            || initialMetadata.publicationDate != publicationDate.value || initialMetadata.bookDescription != descriptionField.value {
            return true
        }
        
        let newMetadata = BookMetadata(book: bookToEdit)
        populateMetadata(newMetadata)
        
        if !initialMetadata.authors.elementsEqual(newMetadata.authors, by: {$0.lastName == $1.lastName && $0.firstNames == $1.firstNames}) {
            return true
        }
        if !initialMetadata.subjects.elementsEqual(newMetadata.subjects, by: {$0 == $1}) {
            return true
        }

        if let existingDataHash = initialCoverImageDataHash, let currentImage = image.value {
            return existingDataHash != MD5(data: UIImagePNGRepresentation(currentImage)!)
        }
        else {
            return !(bookToEdit.coverImage == nil && image.value == nil)
        }
 */
    }
    
    func presentUpdateAlert() {
        let areYouSure = UIAlertController(title: "Confirm Update", message: "Updating from Google Books will overwrite any book metadata changes you have made manually. Are you sure you wish to proceed?", preferredStyle: .alert)
        areYouSure.addAction(UIAlertAction(title: "Update", style: .default){[unowned self] _ in self.updateBookFromGoogle()})
        areYouSure.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(areYouSure, animated: true)
    }
        
    func updateBookFromGoogle() {
        SVProgressHUD.show(withStatus: "Downloading...")
        GoogleBooks.fetch(googleBooksId: bookToEdit.googleBooksId!) { [unowned self] fetchResultPage in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                guard fetchResultPage.result.isSuccess else {
                    SVProgressHUD.showError(withStatus: "Could not update book details")
                    return
                }
                appDelegate.booksStore.update(book: self.bookToEdit, withMetadata: fetchResultPage.result.value!.toBookMetadata())
                self.dismiss {
                    SVProgressHUD.showInfo(withStatus: "Book updated")
                }
            }
        }
    }
    
    func presentDeleteAlert(){
        // We are going to show an action sheet
        let confirmDeleteAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Bring up the action sheet)
        confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) {[unowned self] _ in
            
            // Dismiss this modal view and then delete the book
            self.dismiss(animated: true) {
                self.bookToEdit.delete()
                UserEngagement.logEvent(.deleteBook)
            }
        })
        self.present(confirmDeleteAlert, animated: true, completion: nil)
    }
    
    override func formValidated(isValid: Bool) {
        doneButton.isEnabled = isValid
    }
    
    @IBAction func cancelButtonWasPressed(_ sender: AnyObject) {
        // Check for changes
        if metadataChanges() {
            // Confirm exit dialog
            let confirmExit = UIAlertController(title: "Unsaved changes", message: "Are you sure you want to discard your unsaved changes?", preferredStyle: .actionSheet)
            confirmExit.addAction(UIAlertAction(title: "Discard", style: .destructive){ [unowned self] _ in
                self.dismiss()
            })
            confirmExit.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(confirmExit, animated: true, completion: nil)
        }
        else {
            dismiss()
        }
    }
    
    @IBAction func doneButtonWasPressed(_ sender: AnyObject) {
        // Check the title field is not nil
        guard titleField.value != nil && authors.count >= 1 else { return }
        
        // Load the book metadata into an object from the form values
        let newMetadata = BookMetadata(book: bookToEdit)
        populateMetadata(newMetadata)
        
        // Update the book
        appDelegate.booksStore.update(book: bookToEdit, withMetadata: newMetadata)
        dismiss {
            UserEngagement.logEvent(.editBook)
            UserEngagement.onReviewTrigger()
        }
    }
}
