import Foundation
import CloudKit

extension CKError {
    enum Strategy {
        case retryLater(TimeInterval?)
        case retrySmallerBatch
        case resetChangeToken
        case manualMerge
        case handleInnerErrors([CKRecord.ID: CKError]?)
        case disableSync
        case none
    }

    var strategy: Strategy {
        switch self.code {
        // User did something
        case .managedAccountRestricted, .notAuthenticated, .quotaExceeded, .userDeletedZone, .zoneNotFound:
            return .disableSync

        // Try again later
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .serverResponseLost,
             .internalError, .operationCancelled, .zoneBusy, .requestRateLimited:
            return .retryLater(self.userInfo[CKErrorRetryAfterKey] as? TimeInterval)

        // Try again with smalled batch size
        case .limitExceeded:
            return .retrySmallerBatch

        // Unexpected codes
        case .alreadyShared, .participantMayNeedVerification, .tooManyParticipants, .badContainer, .badDatabase,
             .constraintViolation, .incompatibleVersion, .invalidArguments, .missingEntitlement, .referenceViolation,
             .serverRejectedRequest, .resultsTruncated, .permissionFailure:
            return .none

        // Asset modification
        case .assetFileModified, .assetFileNotFound, .assetNotAvailable:
            return .none

        // Delete change token
        case .changeTokenExpired:
            return .resetChangeToken

        // Data modification
        case .unknownItem, .serverRecordChanged:
            return .manualMerge

        // Process items one-by-one
        case .partialFailure:
            let innerErrors = self.userInfo[CKPartialErrorsByItemIDKey] as! [CKRecord.ID: CKError]
            return .handleInnerErrors(innerErrors)

        // Not sure yet
        case .batchRequestFailed:
            return .none

        }
    }
}
