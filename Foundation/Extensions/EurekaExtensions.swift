import Foundation
import Eureka

extension BaseRow {

    func removeSelf() {
        guard let index = section?.index(of: self) else { return }
        section!.remove(at: index)
    }
}
