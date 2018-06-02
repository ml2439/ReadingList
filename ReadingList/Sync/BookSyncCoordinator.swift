import Foundation
import CoreData

class BookSyncCoordinator: SyncCoordinator {
    init(container: NSPersistentContainer) {
        super.init(container: container,
                   remote: BookConsoleRemote(),
                   upstreamChangeProcessors: [BookInserter(), BookUpdater(), BookDeleter()],
                   downstreamChangeProcessors: [BookDownloader()])
    }
}
