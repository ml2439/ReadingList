import Foundation
import UIKit
import ReadingList_Foundation

class StartFinishButton: BorderedButton {
    enum ButtonState {
        case start
        case finish
        case none
    }

    func setState(_ state: ButtonState) {
        switch state {
        case .start:
            isHidden = false
            setColor(appDelegate.window!.tintColor)
            setTitle("START", for: .normal)
        case .finish:
            isHidden = false
            setColor(.flatGreen)
            setTitle("FINISH", for: .normal)
        case .none:
            isHidden = true
        }
    }
}
