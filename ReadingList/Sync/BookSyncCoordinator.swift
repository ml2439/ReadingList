import Foundation
import CoreData

class BookSyncCoordinator: SyncCoordinator {
    init(container: NSPersistentContainer, remote: BookCloudKitRemote) {
        super.init(container: container,
                   remote: remote,
                   upstreamChangeProcessors: [BookInserter(), BookUpdater(), BookDeleter()],
                   downstreamChangeProcessors: [BookDownloader()])
    }
}
