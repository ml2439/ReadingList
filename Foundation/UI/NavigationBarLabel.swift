import Foundation
import UIKit

class UINavigationBarLabel: UILabel {
    convenience init() {
        self.init(frame: CGRect.zero)
        backgroundColor = .clear
        textAlignment = .center
        textColor = UINavigationBar.appearance().tintColor
        font = UIFont.boldSystemFont(ofSize: 16)
    }
    
    func setTitle(_ title: String?) {
        text = title
        sizeToFit()
    }
}
