import Foundation
import CoreData

class BookSyncCoordinator: SyncCoordinator<BookConsoleRemote> {
    init(container: NSPersistentContainer) {
        super.init(container: container, remote: BookConsoleRemote(), changeProcessors: [])
    }
}
