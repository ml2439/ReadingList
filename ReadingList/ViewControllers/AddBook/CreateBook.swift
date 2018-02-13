import UIKit

class CreateBook: BookMetadataForm {
    
    @IBOutlet weak var nextButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide the ISBN field's section and the delete button
        isbnField.section!.remove(at: isbnField.indexPath!.row)
        updateRow.section!.remove(at: updateRow.indexPath!.row)
        deleteRow.section!.remove(at: deleteRow.indexPath!.row)
    }
    
    override func formValidated(isValid: Bool) {
        nextButton.isEnabled = isValid
    }
    
    @IBAction func cancelButtonWasPressed(_ sender: AnyObject) {
        // Check for changes
        if anyData() {
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let createReadState = segue.destination as? CreateReadState {
            UserEngagement.logEvent(.addManualBook)
            
            let finalBookMetadata = BookMetadata()
            populateMetadata(finalBookMetadata)
            createReadState.bookMetadata = finalBookMetadata
        }
    }
}
