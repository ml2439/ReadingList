import Foundation
import UIKit

class Storyboard {
    static var SearchOnline: UIStoryboard {
        get { return UIStoryboard(name: "SearchOnline", bundle: Bundle.main) }
    }
    
    static var ScanBarcode: UIStoryboard {
        get { return UIStoryboard(name: "ScanBarcode", bundle: Bundle.main) }
    }
    
    static var AddManually: UIStoryboard {
        get { return UIStoryboard(name: "AddManually", bundle: Bundle.main) }
    }
    
    static var AddToList: UIStoryboard {
        get { return UIStoryboard(name: "AddToList", bundle: Bundle.main) }
    }
}

