import Foundation
import CoreData

class SyncCoordinator {
    let viewContext: NSManagedObjectContext
    let syncContext: NSManagedObjectContext
    private let syncGroup = DispatchGroup()

    let upstreamChangeProcessors: [UpstreamChangeProcessor]
    let downstreamChangeProcessors: [DownstreamChangeProcessor]
    let remote: Remote

    init(container: NSPersistentContainer, remote: Remote, upstreamChangeProcessors: [UpstreamChangeProcessor], downstreamChangeProcessors: [DownstreamChangeProcessor]) {
        viewContext = container.viewContext
        viewContext.name = "ViewContext"

        syncContext = container.newBackgroundContext()
        syncContext.name = "SyncContext"
        syncContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump

        self.remote = remote
        self.upstreamChangeProcessors = upstreamChangeProcessors
        self.downstreamChangeProcessors = downstreamChangeProcessors

        // Setup contexts:
        // TODO: determine whether query generations are necessary
        setupQueryGenerations()
        setupContextNotificationObserving()

        // Setup change processors: usually a no-op. Ignore for now. (TODO)

        // Setup application state observation:
        setupApplicationStateObserving()
    }

    /// Performs the provided block on the syncContext queue
    private func perform(block: @escaping () -> Void) {
        syncContext.perform(group: syncGroup, block: block)
    }

    private func setupQueryGenerations() {
        let token = NSQueryGenerationToken.current
        viewContext.perform {
            try! self.viewContext.setQueryGenerationFrom(token)
        }
        syncContext.perform {
            try! self.syncContext.setQueryGenerationFrom(token)
        }
    }

    /**
     Registers Save observers on both the viewContext and the syncContext, handling them by merging the save from
     one context to the other, and also calling `processChangedLocalObjects(_)` on the updated or inserted objects.
    */
    private func setupContextNotificationObserving() {
        func registerForMergeOnSave(from sourceContext: NSManagedObjectContext, to destinationContext: NSManagedObjectContext) {
            // TODO: the returned object could be kept and used to unregister, if needed
            NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: sourceContext, queue: nil) { [weak self] note in
                print("Merging save from \(String(sourceContext.name!)) to \(String(destinationContext.name!))")
                destinationContext.performMergeChanges(from: note)

                // Take the new or modified objects, mapped to the syncContext, and process the
                guard let coordinator = self else { return }
                coordinator.perform {
                    // We unpack the notification here, to make sure it's retained until this point.
                    let updates = note.updatedObjects?.map { $0.inContext(coordinator.syncContext) } ?? []
                    let inserts = note.insertedObjects?.map { $0.inContext(coordinator.syncContext) } ?? []
                    coordinator.processLocalChanges(updates + inserts)
                }
            }
        }

        registerForMergeOnSave(from: syncContext, to: viewContext)
        registerForMergeOnSave(from: viewContext, to: syncContext)
    }

    private static func object(_ object: NSManagedObject, matches fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> Bool {
            return object.entity.name == fetchRequest.entityName
                && fetchRequest.predicate!.evaluate(with: object)
    }

    private func processLocalChanges(_ objects: [NSManagedObject]) {
        for changeProcessor in upstreamChangeProcessors {
            let matching = objects.filter {
                SyncCoordinator.object($0, matches: changeProcessor.unprocessedChangedObjectsRequest)
            }
            guard !matching.isEmpty else { continue }
            changeProcessor.processLocalChanges(matching, context: syncContext, remote: remote)
        }
    }

    private func setupApplicationStateObserving() {
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) { [weak self] _ in
            guard let coordinator = self else { return }
            coordinator.perform {
                // TODO: Why do we do this?
                coordinator.syncContext.refreshAllObjects()
            }
        }
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { [weak self] _ in
            guard let coordinator = self else { return }
            coordinator.perform {
                coordinator.applicationDidBecomeActive()
            }
        }
    }

    func applicationDidBecomeActive() {
        processOutstandingLocalChanges()
        processOutstandingRemoteChanges()
    }

    private func processOutstandingLocalChanges() {
        perform {
            // FUTURE: Could optimize this to only execute a single fetch request per entity.
            var objects: Set<NSManagedObject> = []
            for fetchRequest in self.upstreamChangeProcessors.compactMap({ $0.unprocessedChangedObjectsRequest }) {
                fetchRequest.returnsObjectsAsFaults = false
                let result = try! self.syncContext.fetch(fetchRequest) as! [NSManagedObject]
                objects.formUnion(result)
            }
            self.processLocalChanges(Array(objects))
        }
    }

    private func processOutstandingRemoteChanges() {
        // TODO: Determine whether iCloud sync has started before. If not, fetch all records, not just changes
        self.remote.fetchRecordChanges { changes, callback in
            guard !changes.isEmpty else { return }
            for changeProcessor in self.downstreamChangeProcessors {
                self.perform {
                    changeProcessor.processRemoteChanges(changes, context: self.syncContext) {
                        self.syncContext.saveAndLogIfErrored()
                        callback(true)
                    }
                }
            }
        }
    }
}
