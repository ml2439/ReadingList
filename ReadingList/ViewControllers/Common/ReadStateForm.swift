import Eureka
import UIKit

class ReadStateForm: FormViewController {

    private let readStateKey = "book-read-state"
    private let dateStartedKey = "date-started"
    private let dateFinishedKey = "date-finished"
    private let currentPageKey = "current-page"
    private let notesKey = "notes"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let now = Date()

        form +++ Section(header: "Current State", footer: "")
            <<< SegmentedRow<BookReadState>(readStateKey) {
                $0.options = [.toRead, .reading, .finished]
                // Set a value here so we can be sure that the read state option is *never* null.
                $0.value = .toRead
                $0.onChange {[unowned self] _ in
                    self.validate()
                }
            }
        +++ Section(header: "Reading Log", footer: "") {
            $0.hidden = Condition.function([readStateKey]) {[unowned self] _ in
                return self.readState.value! == .toRead
            }
        }
            <<< DateRow(dateStartedKey) {
                $0.title = "Started"
                $0.maximumDate = Date.startOfToday()
                // Set a value here so we can be sure that the started date is *never* null.
                $0.value = now
                $0.onChange {[unowned self] cell in
                    self.validate()
                }
            }
        
            <<< DateRow(dateFinishedKey) {
                $0.title = "Finished"
                $0.maximumDate = Date.startOfToday()
                $0.hidden = Condition.function([readStateKey]) {[unowned self] _ in
                    return self.readState.value! != .finished
                }
                // Set a value here so we can be sure that the finished date is *never* null.
                $0.value = now
                $0.onChange{ [unowned self] _ in
                    self.validate()
                }
            }
            
            <<< IntRow(currentPageKey) {
                $0.title = "Current Page"
                $0.hidden = Condition.function([readStateKey]) { [unowned self] _ in
                    return self.readState.value! != .reading
                }
                $0.onChange{ [unowned self] _ in
                    self.validate()
                }
            }
        
        +++ Section(header: "Notes", footer: "")
            <<< TextAreaRow(notesKey){
                $0.placeholder = "Add your personal notes here..."
            }
            .cellSetup{ [unowned self] cell, _ in
                cell.height = {return (self.view.frame.height / 3) - 10}
            }
    }
    
    private func validate() {
        if self.readState.value == .finished {
            formValidated(isValid: startedReading.value!.compareIgnoringTime(finishedReading.value!) != .orderedDescending)
        }
        else if self.readState.value == .reading {
            formValidated(isValid: currentPage.value == nil || (currentPage.value! >= 0 && currentPage.value! <= 999999999))
        }
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        self.navigationController?.dismiss(animated: true, completion: completion)
    }
    
    func formValidated(isValid: Bool) {
        // Should be overriden
    }

    var readState: SegmentedRow<BookReadState> {
        get { return form.rowBy(tag: readStateKey) as! SegmentedRow<BookReadState> }
    }
    
    var startedReading: DateRow {
        get { return form.rowBy(tag: dateStartedKey) as! DateRow }
    }
    
    var finishedReading: DateRow {
        get { return form.rowBy(tag: dateFinishedKey) as! DateRow }
    }

    var currentPage: IntRow {
        get { return form.rowBy(tag: currentPageKey) as! IntRow }
    }
    
    var notes: TextAreaRow {
        get { return form.rowBy(tag: notesKey) as! TextAreaRow }
    }
}
