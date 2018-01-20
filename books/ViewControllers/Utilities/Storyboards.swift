//
//  Storyboards.swift
//  books
//
//  Created by Andrew Bennet on 14/10/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

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

extension UIStoryboard {
    func instantiateRoot(withStyle style: UIModalPresentationStyle? = nil) -> UIViewController {
        let vc = self.instantiateInitialViewController()!
        if let style = style {
            vc.modalPresentationStyle = style
        }
        return vc
    }
    
    func rootAsFormSheet() -> UIViewController {
        return instantiateRoot(withStyle: .formSheet)
    }
}
