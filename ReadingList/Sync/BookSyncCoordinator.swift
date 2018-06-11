import Foundation
import CoreData

class BookSyncCoordinator: SyncCoordinator {
    init(container: NSPersistentContainer) {
        super.init(container: container,
                   upstreamChangeProcessors: [BookUploader(), BookDeleter()],
                   downstreamChangeProcessors: [BookDownloader()])
    }
}
