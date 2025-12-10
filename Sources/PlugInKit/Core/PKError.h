//
//  PKError.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for PlugInKit errors
FOUNDATION_EXPORT NSErrorDomain const PKErrorDomain;

/// Comprehensive error codes for PlugInKit
typedef NS_ERROR_ENUM(PKErrorDomain, PKError) {
    // Discovery errors (1000-1099)
    PKErrorPlugInNotFound           = 1000,
    PKErrorInvalidPlugInBundle      = 1001,
    PKErrorMissingInfoPlist         = 1002,
    PKErrorMissingXPCService        = 1003,
    PKErrorInvalidBundleStructure   = 1004,
    PKErrorDuplicatePlugIn          = 1005,

    // Connection errors (1100-1199)
    PKErrorConnectionFailed         = 1100,
    PKErrorConnectionInterrupted    = 1101,
    PKErrorConnectionInvalidated    = 1102,
    PKErrorConnectionTimeout        = 1103,
    PKErrorConnectionNotReady       = 1104,
    PKErrorConnectionAlreadyActive  = 1105,

    // Communication errors (1200-1299)
    PKErrorInvalidMessage           = 1200,
    PKErrorMessageTimeout           = 1201,
    PKErrorEncodingFailed           = 1202,
    PKErrorDecodingFailed           = 1203,
    PKErrorInvalidResponse          = 1204,
    PKErrorMessageTooLarge          = 1205,

    // Compatibility errors (1300-1399)
    PKErrorIncompatibleVersion      = 1300,
    PKErrorMissingCapability        = 1301,
    PKErrorProtocolMismatch         = 1302,
    PKErrorHostVersionTooOld        = 1303,
    PKErrorHostVersionTooNew        = 1304,

    // Plugin errors (1400-1499)
    PKErrorPlugInInitializationFailed = 1400,
    PKErrorPlugInNotResponding      = 1401,
    PKErrorPlugInCrashed            = 1402,
    PKErrorPlugInTerminated         = 1403,
    PKErrorPlugInSuspended          = 1404,

    // Permission errors (1500-1599)
    PKErrorPermissionDenied         = 1500,
    PKErrorSandboxViolation         = 1501,
    PKErrorCodeSignatureInvalid     = 1502,
    PKErrorEntitlementMissing       = 1503,

    // Resource errors (1600-1699)
    PKErrorResourceLimitExceeded    = 1600,
    PKErrorMemoryLimitExceeded      = 1601,
    PKErrorCPULimitExceeded         = 1602,
    PKErrorTooManyConnections       = 1603,
    PKErrorQueueFull                = 1604,

    // Operation errors (1700-1799)
    PKErrorOperationCancelled       = 1700,
    PKErrorOperationTimedOut        = 1701,
    PKErrorOperationFailed          = 1702,
    PKErrorInvalidState             = 1703,
    PKErrorInvalidArgument          = 1704,

    // Hot-reload errors (1800-1899)
    PKErrorReloadFailed             = 1800,
    PKErrorReloadInProgress         = 1801,
    PKErrorStateMigrationFailed     = 1802,
    PKErrorVersionDowngradeNotAllowed = 1803,
};

/// User info keys for additional error information
FOUNDATION_EXPORT NSErrorUserInfoKey const PKErrorPlugInIdentifierKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const PKErrorPlugInVersionKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const PKErrorRequiredVersionKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const PKErrorActualVersionKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const PKErrorMissingCapabilityKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const PKErrorRecoverySuggestionKey;

/// Convenience category for creating PlugInKit errors
@interface NSError (PlugInKit)

/// Create a PlugInKit error with description
/// @param code Error code
/// @param description Localized description
+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description;

/// Create a PlugInKit error with description and underlying error
/// @param code Error code
/// @param description Localized description
/// @param underlyingError Underlying error that caused this error
+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description
                 underlyingError:(nullable NSError *)underlyingError;

/// Create a PlugInKit error with description and user info
/// @param code Error code
/// @param description Localized description
/// @param userInfo Additional user info dictionary
+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description
                        userInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;

/// Create a PlugInKit error with recovery options
/// @param code Error code
/// @param description Localized description
/// @param recoverySuggestion Recovery suggestion
/// @param recoveryOptions Array of recovery option strings
+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description
                recoverySuggestion:(nullable NSString *)recoverySuggestion
                  recoveryOptions:(nullable NSArray<NSString *> *)recoveryOptions;

/// Get human-readable error category
@property (nonatomic, copy, readonly) NSString *pk_errorCategory;

/// Check if error is recoverable
@property (nonatomic, assign, readonly) BOOL pk_isRecoverable;

/// Check if error is transient (retry may succeed)
@property (nonatomic, assign, readonly) BOOL pk_isTransient;

@end

NS_ASSUME_NONNULL_END
