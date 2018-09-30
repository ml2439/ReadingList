import Foundation
import UIKit

public class NoCancelButtonSearchController: UISearchController {
    let noCancelButtonSearchBar = NoCancelButtonSearchBar()
    public override var searchBar: UISearchBar { return noCancelButtonSearchBar }
}

class NoCancelButtonSearchBar: UISearchBar {
    override func setShowsCancelButton(_ showsCancelButton: Bool, animated: Bool) { /* void */ }
}
