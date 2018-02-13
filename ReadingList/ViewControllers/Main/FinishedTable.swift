import UIKit
import DZNEmptyDataSet

class FinishedTable: BookTable {

    override var navigationItemTitle: String {
        get { return "Finished" }
    }
    
    override func viewDidLoad() {
        readStates = [.finished]
        super.viewDidLoad()
    }
    
    override func footerText() -> String? {
        guard let finishedSectionIndex = self.sectionIndex(forReadState: .finished) else { return nil }
        
        let finishedCount = tableView(tableView, numberOfRowsInSection: finishedSectionIndex)
        return "Finished: \(finishedCount) book\(finishedCount == 1 ? "" : "s")"
    }
}
