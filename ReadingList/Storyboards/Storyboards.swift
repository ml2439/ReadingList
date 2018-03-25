import Foundation
import UIKit

class Storyboard {
    static var SearchOnline: UIStoryboard {
        get { return UIStoryboard(name: "SearchOnline", bundle: Bundle.main) }
    }
    
    static var ScanBarcode: UIStoryboard {
        get { return UIStoryboard(name: "ScanBarcode", bundle: Bundle.main) }
    }
    
    static var AddToList: UIStoryboard {
        get { return UIStoryboard(name: "AddToList", bundle: Bundle.main) }
    }
    
    static var BookTable: UIStoryboard {
        get { return UIStoryboard(name: "BookTable", bundle: Bundle.main) }
    }
    
    static var Organise: UIStoryboard {
        get { return UIStoryboard(name: "Organise", bundle: Bundle.main) }
    }
    
    static var Settings: UIStoryboard {
        get { return UIStoryboard(name: "Settings", bundle: Bundle.main) }
    }
}

