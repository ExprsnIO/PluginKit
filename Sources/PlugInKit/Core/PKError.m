//
//  PKError.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKError.h"

NSErrorDomain const PKErrorDomain = @"com.pluginkit.error";

NSErrorUserInfoKey const PKErrorPlugInIdentifierKey = @"PKErrorPlugInIdentifier";
NSErrorUserInfoKey const PKErrorPlugInVersionKey = @"PKErrorPlugInVersion";
NSErrorUserInfoKey const PKErrorRequiredVersionKey = @"PKErrorRequiredVersion";
NSErrorUserInfoKey const PKErrorActualVersionKey = @"PKErrorActualVersion";
NSErrorUserInfoKey const PKErrorMissingCapabilityKey = @"PKErrorMissingCapability";
NSErrorUserInfoKey const PKErrorRecoverySuggestionKey = @"PKErrorRecoverySuggestion";

@implementation NSError (PlugInKit)

+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description {
    return [self pk_errorWithCode:code
                      description:description
                         userInfo:nil];
}

+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description
                 underlyingError:(NSError *)underlyingError {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = description;

    if (underlyingError) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }

    return [NSError errorWithDomain:PKErrorDomain
                               code:code
                           userInfo:userInfo];
}

+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description
                        userInfo:(NSDictionary<NSErrorUserInfoKey, id> *)userInfo {
    NSMutableDictionary *fullUserInfo = [NSMutableDictionary dictionary];
    fullUserInfo[NSLocalizedDescriptionKey] = description;

    if (userInfo) {
        [fullUserInfo addEntriesFromDictionary:userInfo];
    }

    return [NSError errorWithDomain:PKErrorDomain
                               code:code
                           userInfo:fullUserInfo];
}

+ (instancetype)pk_errorWithCode:(PKError)code
                     description:(NSString *)description
                recoverySuggestion:(NSString *)recoverySuggestion
                  recoveryOptions:(NSArray<NSString *> *)recoveryOptions {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = description;

    if (recoverySuggestion) {
        userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion;
    }

    if (recoveryOptions) {
        userInfo[NSLocalizedRecoveryOptionsErrorKey] = recoveryOptions;
    }

    return [NSError errorWithDomain:PKErrorDomain
                               code:code
                           userInfo:userInfo];
}

- (NSString *)pk_errorCategory {
    if (![self.domain isEqualToString:PKErrorDomain]) {
        return @"Unknown";
    }

    NSInteger code = self.code;

    if (code >= 1000 && code < 1100) return @"Discovery";
    if (code >= 1100 && code < 1200) return @"Connection";
    if (code >= 1200 && code < 1300) return @"Communication";
    if (code >= 1300 && code < 1400) return @"Compatibility";
    if (code >= 1400 && code < 1500) return @"Plugin";
    if (code >= 1500 && code < 1600) return @"Permission";
    if (code >= 1600 && code < 1700) return @"Resource";
    if (code >= 1700 && code < 1800) return @"Operation";
    if (code >= 1800 && code < 1900) return @"Hot-Reload";

    return @"Unknown";
}

- (BOOL)pk_isRecoverable {
    if (![self.domain isEqualToString:PKErrorDomain]) {
        return NO;
    }

    NSInteger code = self.code;

    // These errors are generally recoverable
    switch (code) {
        case PKErrorConnectionInterrupted:
        case PKErrorConnectionTimeout:
        case PKErrorMessageTimeout:
        case PKErrorPlugInNotResponding:
        case PKErrorOperationCancelled:
        case PKErrorOperationTimedOut:
        case PKErrorQueueFull:
        case PKErrorReloadFailed:
            return YES;

        default:
            return NO;
    }
}

- (BOOL)pk_isTransient {
    if (![self.domain isEqualToString:PKErrorDomain]) {
        return NO;
    }

    NSInteger code = self.code;

    // These errors may resolve on retry
    switch (code) {
        case PKErrorConnectionFailed:
        case PKErrorConnectionInterrupted:
        case PKErrorConnectionTimeout:
        case PKErrorMessageTimeout:
        case PKErrorPlugInNotResponding:
        case PKErrorResourceLimitExceeded:
        case PKErrorQueueFull:
        case PKErrorOperationTimedOut:
            return YES;

        default:
            return NO;
    }
}

@end
