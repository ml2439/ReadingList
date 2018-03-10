import Crashlytics
import Fabric
import Foundation

extension Fabric {
    static func log(_ string: String) {
        CLSLogv("%@", getVaList([string]))
    }
}
