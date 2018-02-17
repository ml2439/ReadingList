import UIKit
import DZNEmptyDataSet

class FinishedTable: BookTable {
    
    override func viewDidLoad() {
        readStates = [.finished]
        navigationItemTitle = "Finished"
        super.viewDidLoad()
    }
    
    override func footerText() -> String? {
        guard let finishedSectionIndex = self.sectionIndex(forReadState: .finished) else { return nil }
        
        let finishedCount = tableViewDataSource.tableView(tableView, numberOfRowsInSection: finishedSectionIndex)
        return "Finished: \(finishedCount) book\(finishedCount == 1 ? "" : "s")"
    }
}
