import Foundation
import UIKit

class StartFinishButton: BorderedButton {
    enum State {
        case start
        case finish
        case none
    }
    
    func setState(_ state: State) {
        switch state {
        case .start:
            isHidden = false
            setColor(UIColor.buttonBlue)
            setTitle("START", for: .normal)
        case .finish:
            isHidden = false
            setColor(UIColor.flatGreen)
            setTitle("FINISH", for: .normal)
        case .none:
            isHidden = true
        }
    }
}
