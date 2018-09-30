import Foundation
import UIKit

public class UINavigationBarLabel: UILabel {
    public convenience init() {
        self.init(frame: .zero)
        backgroundColor = .clear
        textAlignment = .center
        textColor = UINavigationBar.appearance().tintColor
        font = UIFont.boldSystemFont(ofSize: 16)
    }

    public func setTitle(_ title: String?) {
        text = title
        sizeToFit()
    }
}
