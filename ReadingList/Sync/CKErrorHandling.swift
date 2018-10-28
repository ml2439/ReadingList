import Foundation
import CloudKit

extension CKError {
    var innerErrors: [CKRecord.ID: CKError]? {
        return self.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: CKError]
    }

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
            return .handleInnerErrors(innerErrors!)

        // Not sure yet
        case .batchRequestFailed:
            return .none

        }
    }
}

extension CKError.Code {
    /**
     For logging and debugging purposes: a string representation of the enum name.
     */
    var name: String {
        switch self {
        case .internalError: return "internalError"
        case .networkUnavailable: return "networkUnavailable"
        case .networkFailure: return "networkFailure"
        case .badContainer: return "badContainer"
        case .serviceUnavailable: return "serviceUnavailable"
        case .requestRateLimited: return "requestRateLimited"
        case .missingEntitlement: return "missingEntitlement"
        case .notAuthenticated: return "notAuthenticated"
        case .permissionFailure: return "permissionFailure"
        case .unknownItem: return "unknownItem"
        case .invalidArguments: return "invalidArguments"
        case .resultsTruncated: return "resultsTruncated"
        case .serverRecordChanged: return "serverRecordChanged"
        case .serverRejectedRequest: return "serverRejectedRequest"
        case .assetFileNotFound: return "assetFileNotFound"
        case .assetFileModified: return "assetFileModified"
        case .incompatibleVersion: return "incompatibleVersion"
        case .constraintViolation: return "constraintViolation"
        case .operationCancelled: return "operationCancelled"
        case .changeTokenExpired: return "changeTokenExpired"
        case .batchRequestFailed: return "batchRequestFailed"
        case .zoneBusy: return "zoneBusy"
        case .badDatabase: return "badDatabase"
        case .quotaExceeded: return "quotaExceeded"
        case .zoneNotFound: return "zoneNotFound"
        case .limitExceeded: return "limitExceeded"
        case .userDeletedZone: return "userDeletedZone"
        case .tooManyParticipants: return "tooManyParticipants"
        case .alreadyShared: return "alreadyShared"
        case .referenceViolation: return "referenceViolation"
        case .managedAccountRestricted: return "managedAccountRestricted"
        case .participantMayNeedVerification: return "participantMayNeedVerification"
        case .serverResponseLost: return "serverResponseLost"
        case .assetNotAvailable: return "assetNotAvailable"
        case .partialFailure: return "partialFailure"
        }
    }

}
