import Foundation
import UIKit

class EditReadState: ReadStateForm {
    
    var bookToEdit: Book!
    
    @IBOutlet weak var doneButton: UIBarButtonItem!

    override func viewDidLoad(){
        super.viewDidLoad()

        navigationItem.title = bookToEdit.title
        
        // Load the existing values on to the form; if dates are missing, use the current date
        // if the date entry field becomes visible
        readState.value = bookToEdit.readState
        if let started = bookToEdit.startedReading {
            startedReading.value = started
        }
        if let finished = bookToEdit.finishedReading {
            finishedReading.value = finished
        }
        
        currentPage.value = bookToEdit.currentPage == nil ? nil : Int(truncating: bookToEdit.currentPage!)
        notes.value = bookToEdit.notes
    }
    
    override func formValidated(isValid: Bool) {
        doneButton.isEnabled = isValid
    }
    
    @IBAction func doneWasPressed(_ sender: UIBarButtonItem) {
        self.view.endEditing(true)
        
        // Create an object representation of the form values
        let newReadStateInfo = BookReadingInformation(readState: readState.value!, startedWhen: startedReading.value, finishedWhen: finishedReading.value, currentPage: currentPage.value)
        
        // Update the book
        appDelegate.booksStore.update(book: bookToEdit, withReadingInformation: newReadStateInfo, readingNotes: notes.value)
        
        self.navigationController?.dismiss(animated: true){
            UserEngagement.logEvent(.editReadState)
            UserEngagement.onReviewTrigger()
        }
    }
    
    func anyChanges() -> Bool {
        if readState.value != bookToEdit.readState || currentPage.value != bookToEdit.currentPage?.intValue || notes.value != bookToEdit.notes {
            return true
        }
        
        if readState.value == .toRead {
            return false
        }
        if readState.value == .reading {
            return startedReading.value != bookToEdit.startedReading
        }
        else {
            return startedReading.value != bookToEdit.startedReading || finishedReading.value != bookToEdit.finishedReading
        }
    }
    
    @IBAction func cancelWasPressed(_ sender: UIBarButtonItem) {
        if anyChanges() {
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
}
