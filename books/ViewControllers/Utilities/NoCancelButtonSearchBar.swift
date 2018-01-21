//
//  NoCancelButtonSearchBar.swift
//  books
//
//  Created by Andrew Bennet on 08/10/2017.
//  Copyright © 2017 Andrew Bennet. All rights reserved.
//

import Foundation
import UIKit

class NoCancelButtonSearchController: UISearchController {
    let noCancelButtonSearchBar = NoCancelButtonSearchBar()
    override var searchBar: UISearchBar { return noCancelButtonSearchBar }
}

class NoCancelButtonSearchBar: UISearchBar {
    override func setShowsCancelButton(_ showsCancelButton: Bool, animated: Bool) { /* void */ }
}

extension UISearchBar {
    var isActive: Bool {
        get {
            return isUserInteractionEnabled
        }
        set {
            isUserInteractionEnabled = newValue
            alpha = newValue ? 1.0 : 0.5
        }
    }

    var isActiveOrVisible: Bool {
        get {
            if #available(iOS 11.0, *) {
                return isActive
            }
            else {
                return !isHidden
            }
        }
        set {
            // iOS >10 search bars can be made hidden without much consequence;
            // iOS 11 search bars are part of navigation items, which makes hiding them look weird. Instead we "disable" them.
            if #available(iOS 11.0, *) {
                isActive = newValue
            }
            else {
                isHidden = !newValue
            }
        }
    }
}
