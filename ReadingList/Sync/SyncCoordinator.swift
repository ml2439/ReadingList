import Foundation
import CoreData
import UIKit
import CloudKit

class SyncCoordinator {
    let viewContext: NSManagedObjectContext
    let syncContext: NSManagedObjectContext

    let upstreamChangeProcessors: [UpstreamChangeProcessor]
    let downstreamChangeProcessors: [DownstreamChangeProcessor]
    let remote = BookCloudKitRemote()

    private var contextSaveNotificationObservers = [NSObjectProtocol]()

    init(container: NSPersistentContainer) {
        viewContext = container.viewContext
        viewContext.name = "viewContext"

        syncContext = container.newBackgroundContext()
        syncContext.name = "syncContext"
        syncContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump // FUTURE: Add a custom merge policy

        self.upstreamChangeProcessors = [BookInserter(syncContext), BookUpdater(syncContext), BookDeleter(syncContext)]
        self.downstreamChangeProcessors = [BookDownloader(syncContext)]
    }

    /**
     
     */
    func start() {
        //setSyncContextQueryGeneration()
        startContextNotificationObserving()
        processPendingChanges()
    }

    /**
     
    */
    func stop() {
        stopContextNotificationObserving()
    }

    private func setSyncContextQueryGeneration() {
        syncContext.perform {
            let token = NSQueryGenerationToken.current
            try! self.syncContext.setQueryGenerationFrom(token)
            self.syncContext.refreshAllObjects()
        }
    }

    /**
     Registers Save observers on both the viewContext and the syncContext, handling them by merging the save from
     one context to the other, and also calling `processChangedLocalObjects(_)` on the updated or inserted objects.
    */
    private func startContextNotificationObserving() {
        guard contextSaveNotificationObservers.isEmpty else { print("Observers already registered"); return }

        func registerForMergeOnSave(from sourceContext: NSManagedObjectContext, to destinationContext: NSManagedObjectContext) {
            let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: sourceContext, queue: nil) { [weak self] note in
                print("Merging save from \(String(sourceContext.name!)) to \(String(destinationContext.name!))")
                destinationContext.performMergeChanges(from: note)

                // Take the new or modified objects, mapped to the syncContext, and process
                guard let coordinator = self else { return }
                coordinator.syncContext.perform {
                    // We unpack the notification here, to make sure it's retained until this point.
                    let updates = note.updatedObjects?.map { $0.inContext(coordinator.syncContext) } ?? []
                    let inserts = note.insertedObjects?.map { $0.inContext(coordinator.syncContext) } ?? []
                    coordinator.processPendingLocalChanges(objects: updates + inserts)
                }
            }
            contextSaveNotificationObservers.append(observer)
        }

        registerForMergeOnSave(from: syncContext, to: viewContext)
        registerForMergeOnSave(from: viewContext, to: syncContext)
    }

    private func stopContextNotificationObserving() {
        contextSaveNotificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        contextSaveNotificationObservers.removeAll()
    }

    func processPendingChanges() {
        processPendingRemoteChanges()

        syncContext.perform {
            self.processPendingLocalChanges()
        }
    }

    private var objectsBeingProcessed = Set<NSManagedObject>()

    private func processPendingLocalChanges(objects: [NSManagedObject]? = nil) {
        for changeProcessor in self.upstreamChangeProcessors {
            let pendingObjects: [NSManagedObject]
            if let objects = objects {
                pendingObjects = objects.filter { object($0, isPendingFor: changeProcessor) && !objectsBeingProcessed.contains($0) }
            } else {
                pendingObjects = self.pendingObjects(for: changeProcessor).filter { !objectsBeingProcessed.contains($0) }
            }

            if !pendingObjects.isEmpty {
                objectsBeingProcessed.formUnion(pendingObjects)
                changeProcessor.processLocalChanges(pendingObjects, remote: self.remote) { [weak self] in
                    self?.objectsBeingProcessed.subtract(pendingObjects)
                }
            }
        }
    }

    func processPendingRemoteChanges(applicationCallback: ((UIBackgroundFetchResult) -> Void)? = nil) {
        syncContext.perform {
            let changeToken = ChangeToken.get(fromContext: self.syncContext, for: self.remote.bookZoneID)?.changeToken
            self.remote.fetchRecordChanges(changeToken: changeToken) { changes in
                guard !changes.isEmpty else { return }
                for changeProcessor in self.downstreamChangeProcessors {
                    changeProcessor.processRemoteChanges(from: self.remote.bookZoneID, changes: changes, completion: nil)
                }
            }
        }
    }

    private func pendingObjects(for changeProcessor: UpstreamChangeProcessor) -> [NSManagedObject] {
        let fetchRequest = changeProcessor.unprocessedChangedObjectsRequest
        fetchRequest.returnsObjectsAsFaults = false
        return try! syncContext.fetch(fetchRequest) as! [NSManagedObject]
    }

    private func object(_ object: NSManagedObject, isPendingFor changeProcessor: UpstreamChangeProcessor) -> Bool {
        let fetchRequest = changeProcessor.unprocessedChangedObjectsRequest
        // Entity name comparison is done since the NSEntityDescription is not necessarily present until a fetch has been peformed
        return object.entity.name == fetchRequest.entityName && fetchRequest.predicate?.evaluate(with: object) != false
    }
}
