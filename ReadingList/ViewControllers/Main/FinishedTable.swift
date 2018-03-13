import UIKit

class FinishedTable: BookTable {
    
    override func viewDidLoad() {
        readStates = [.finished]
        super.viewDidLoad()
    }

}
