import Foundation
import UIKit

class PreviewingNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        return self.topViewController!.previewActionItems
    }
}
