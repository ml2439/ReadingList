import Foundation
import CoreSpotlight
import os.log
import ReadingList_Foundation

class UpgradeAction {
    let id: Int
    let action: () -> Void

    init(id: Int, action: @escaping () -> Void) {
        self.id = id
        self.action = action
    }
}

class UpgradeManager {
    let actions = [

        // At some point we desupported spotlight indexing, so deindex everything
        UpgradeAction(id: 1) {
            if CSSearchableIndex.isIndexingAvailable() {
                os_log("Deleting all searchable spotlight items")
                CSSearchableIndex.default().deleteAllSearchableItems()
            }
        },

        // Migrate the legacy UserDefault settings used for table sort order storage, but only if
        // this has not already been performed by the app already during normal operation.
        UpgradeAction(id: 2) {
            os_log("Migrating table sort order UserDefaults settings")

            // Legacy sort orders: byDate = 0; byTitle = 1; byAuthor = 2
            let legacyTableSortOrderKey = "tableSortOrder"
            guard let legacyTableSortOrder = UserDefaults.standard.object(forKey: legacyTableSortOrderKey) as? Int else {
                os_log("No legacy table sort order settings found; no need for migration")
                return
            }

            let nonLegacySettings = [UserSettingsCollection.toReadSort, UserSettingsCollection.readingSort,
                                     UserSettingsCollection.finishedSort]
            for setting in nonLegacySettings {
                guard UserDefaults.standard.object(forKey: setting.key) == nil else {
                    os_log("Value already exists for %{public}s; no migration.", setting.key)
                    continue
                }
                os_log("Migrating value for %{public}s from legacy value %d.", setting.key, legacyTableSortOrder)
                if legacyTableSortOrder == 1 {
                    UserDefaults.standard[setting] = .title
                } else if legacyTableSortOrder == 2 {
                    UserDefaults.standard[setting] = .author
                }
            }

            // No need for the legacy setting now: remove it
            UserDefaults.standard.removeObject(forKey: legacyTableSortOrderKey)
        },

        // Previous versions of the app stored the persistent store in a non-default location.
        // This file move was previously attempted every launch; the vast majority of users
        // will already have their store in the new location.
        UpgradeAction(id: 3) {
            PersistentStoreManager.moveStoreFromLegacyLocationIfNecessary()
        }
    ]

    /**
     Performs any necessary upgrade actions required, prior to the initialisation of the persistent store.
    */
    func performNecessaryUpgradeActions() {
        // Work out what our threshold should be when considering which upgrade actions to apply
        let threshold: Int?
        if let lastAppliedUpgradeAction = UserDefaults.standard[.lastAppliedUpgradeAction] {
            threshold = lastAppliedUpgradeAction
        } else {
            let startupCount = UserDefaults.standard[.appStartupCount]
            if startupCount > 0 {
                os_log("No record of applying actions, but startup count is %d: will run upgrade actions anyway.", startupCount)
                // Use 0 as the threshold when applying upgrade actions when we don't know what version we came from.
                // This will apply them all.
                threshold = 0
            } else {
                threshold = nil
            }
        }

        // If we have a threshold, apply the relevant actions.
        if let threshold = threshold {
            applyActions(threshold: threshold)
        } else {
            os_log("First launch: no upgrade actions to run.")
        }

        // Now that we have applied any necessary actions, update the storage of the most recent started version
        UserDefaults.standard[.lastAppliedUpgradeAction] = actions.last!.id
    }

    private func applyActions(threshold: Int) {
        // We can exit early if the threshold is same version as the last upgrade action id
        if threshold == actions.last?.id {
            os_log("No upgrade actions to apply")
            return
        }

        // Look for relevant actions to apply; run each in order that match
        let relevantActions = actions.filter { $0.id > threshold }
        relevantActions.forEach { action in
            os_log("Running upgrade action with id %d", action.id)
            action.action()
        }
        if !relevantActions.isEmpty {
            os_log("All %d upgrade actions completed", relevantActions.count)
        }
    }
}
