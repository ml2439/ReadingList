import Foundation
import CoreData
import UIKit

class SyncCoordinator {
    let viewContext: NSManagedObjectContext
    let syncContext: NSManagedObjectContext
    private let syncGroup = DispatchGroup()
    
    let changeProcessors = [ChangeProcessor]() // TODO: implement
    
    let remote: Remote? // TODO: implement

    init(container: NSPersistentContainer) {
        viewContext = container.viewContext
        syncContext = container.newBackgroundContext()
        syncContext.name = "SyncCoordinator"

        // Setup contexts:
        // TODO: determine whether query generations are necessary
        setupQueryGenerations()
        setupContextNotificationObserving()
        
        // Setup change processors: usually a no-op. Ignore for now.
        
        // Setup application state observation:
        setupApplicationStateObserving()
        
        if UIApplication.shared.applicationState == .active {
            applicationDidBecomeActive()
        }
    }
    
    /// Performs the provided block on the syncContext queue
    private func perform(block: @escaping () -> ()) {
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
                destinationContext.performMergeChanges(from: note)
                
                // Take the new or modified objects, mapped to the syncContext, and process the
                guard let coordinator = self else { return }
                coordinator.syncContext.perform(group: coordinator.syncGroup) {
                    // We unpack the notification here, to make sure it's retained until this point.
                    let updates = note.updatedObjects?.map{ $0.inContext(coordinator.syncContext) } ?? []
                    let inserts = note.insertedObjects?.map{ $0.inContext(coordinator.syncContext) } ?? []
                    coordinator.processLocalChanges(updates + inserts)
                }
            }
        }
        
        registerForMergeOnSave(from: syncContext, to: viewContext)
        registerForMergeOnSave(from: viewContext, to: syncContext)
    }
    
    private func processLocalChanges(_ objects: [NSManagedObject]) {
        for changeProcessor in self.changeProcessors {
            changeProcessor.processChangedLocalObjects(objects)
        }
    }
    
    private func setupApplicationStateObserving() {
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) { [weak self] note in
            guard let observer = self else { return }
            observer.perform {
                // TODO: Why do we do this?
                observer.syncContext.refreshAllObjects()
            }
        }
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { [weak self] note in
            guard let observer = self else { return }
            observer.perform {
                observer.applicationDidBecomeActive()
            }
        }
    }
    
    func applicationDidBecomeActive() {
        fetchLocallyTrackedObjects()
        fetchRemoteDataForApplicationDidBecomeActive()
    }
    
    private func fetchLocallyTrackedObjects() {
        perform {
            // FUTURE: Could optimize this to only execute a single fetch request per entity.
            var objects: Set<NSManagedObject> = []
            for cp in self.changeProcessors {
                guard let fetchRequest = cp.fetchRequestForLocallyTrackedObjects() else { continue }
                fetchRequest.returnsObjectsAsFaults = false
                let result = try! self.syncContext.fetch(fetchRequest) as! [NSManagedObject]
                objects.formUnion(result)
            }
            self.processLocalChanges(Array(objects))
        }
    }
    
    /*
    fileprivate func fetchRemoteDataForApplicationDidBecomeActive() {
        switch Mood.count(in: context) {
        case 0: self.fetchLatestRemoteData()
        default: self.fetchNewRemoteData()
        }
    }
    
    fileprivate func fetchLatestRemoteData() {
        perform {
            for changeProcessor in self.changeProcessors {
                changeProcessor.fetchLatestRemoteRecords(in: self)
                self.delayedSaveOrRollback()
            }
        }
    }
    
    fileprivate func fetchNewRemoteData() {
      remote.fetchNewMoods { changes, callback in
            self.processRemoteChanges(changes) {
                self.perform {
                    self.context.delayedSaveOrRollback(group: self.syncGroup) { success in
                        callback(success)
                    }
                }
            }
        }
    }
    
    fileprivate func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>], completion: @escaping () -> ()) {
        self.changeProcessors.asyncForEach(completion: completion) { changeProcessor, innerCompletion in
            perform {
                changeProcessor.processRemoteChanges(changes, in: self, completion: innerCompletion)
            }
        }
    }
 */
}

