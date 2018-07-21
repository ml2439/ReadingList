import Foundation
import UIKit
import ReadingList_Foundation

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
            setColor(.buttonBlue)
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
