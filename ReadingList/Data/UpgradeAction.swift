import Foundation
import CoreSpotlight
import os.log
import ReadingList_Foundation

class UpgradeAction {
    let version: Version
    let action: () -> Void

    init(version: Version, action: @escaping () -> Void) {
        self.version = version
        self.action = action
    }
}

class UpgradeActionApplier {
    let actions = [
        
        // This version removed support for spotlight indexing, so deindex everything
        UpgradeAction(version: Version(1, 7, 1)) {
            if CSSearchableIndex.isIndexingAvailable() {
                os_log("Deleting all searchable spotlight items")
                CSSearchableIndex.default().deleteAllSearchableItems()
            }
        },
        
        // Migrate the legacy UserDefault settings used for table sort order storage, but only if
        // this has not already been performed by the app already.
        UpgradeAction(version: Version(1, 10, 0)) {
            os_log("Migrating table sort order UserDefaults settings")

            // Legacy sort orders: byDate = 0; byTitle = 1; byAuthor = 2
            guard let legacyTableSortOrder = UserDefaults.standard.object(forKey: "tableSortOrder") as? Int else {
                os_log("No legacy table sort order settings found; no need for migration")
                return
            }

            let nonLegacySettings = [UserSettingsCollection.toReadSortOrder, UserSettingsCollection.readingSortOrder,
                                     UserSettingsCollection.finishedSortOrder]
            for setting in nonLegacySettings {
                guard UserDefaults.standard.object(forKey: setting.key) == nil else {
                    os_log("Value already exists for %{public}s; no migration.", setting.key)
                    continue
                }
                os_log("Migrating value for %{public}s from legacy value %d.", setting.key, legacyTableSortOrder)
                if legacyTableSortOrder == 1 {
                    UserDefaults.standard[setting] = .byTitle
                } else if legacyTableSortOrder == 2 {
                    UserDefaults.standard[setting] = .byAuthor
                }
            }
        }
    ]

    func performUpgrade() {
        // Work out what our threshold should be when considering which upgrade actions to apply
        let threshold: [Int]?
        if let mostRecentlyStartedVersion = UserDefaults.standard[.mostRecentStartedVersion] {
            threshold = mostRecentlyStartedVersion
        } else {
            let startupCount = UserDefaults.standard[.appStartupCount]
            if startupCount > 0 {
                os_log("No record of most recently started version, but startup count is %d: will run upgrade actions anyway.", startupCount)
                // Use 1.7.0 as the threshold when applying upgrade actions when we don't know what version we came from.
                // This will apply them all.
                threshold = [1, 7, 0]
            } else {
                threshold = nil
            }
        }
        
        // If we have a threshold, apply the relevant actions.
        if let threshold = threshold {
            guard let versionThreshold = Version(threshold) else { preconditionFailure("Bad version format: \(threshold)") }
            applyActions(threshold: versionThreshold)
        } else {
            os_log("First launch: no upgrade actions to run.")
        }

        // Now that we have applied any necessary actions, update the storage of the most recent started version
        UserDefaults.standard[.mostRecentStartedVersion] = BuildInfo.version.components
    }
    
    private func applyActions(threshold versionThreshold: Version) {
        // We can exit early if this is the same version as the last booted version
        if versionThreshold == BuildInfo.version {
            os_log("No version difference; no upgrade actions to apply")
            return
        }
        
        // Look for relevant actions to apply; run each in order that match
        let relevantActions = actions.filter { $0.version > versionThreshold }
        relevantActions.forEach { action in
            os_log("Running upgrade action for version %{public}s", action.version.description)
            action.action()
        }
        if !relevantActions.isEmpty {
            os_log("All %d upgrade actions completed", relevantActions.count)
        }
    }
}
