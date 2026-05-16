//
//  PKPlugInManager+Compatibility.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+Compatibility.h"
#import "PKError.h"
#import "PKLogger.h"
#import "../../PlugInKitProtocol/PKPlugInDependency.h"
#import <objc/runtime.h>

// Keys for Info.plist
static NSString *const PKMinimumHostVersionKey = @"PKMinimumHostVersion";
static NSString *const PKMaximumHostVersionKey = @"PKMaximumHostVersion";
static NSString *const PKProtocolVersionKey = @"PKProtocolVersion";
static NSString *const PKRequiredCapabilitiesKey = @"PKRequiredCapabilities";
static NSString *const PKProvidedCapabilitiesKey = @"PKProvidedCapabilities";
static NSString *const PKRequiredPlugInsKey = @"PKRequiredPlugins";
static NSString *const PKDeprecatedAtVersionKey = @"PKDeprecatedAtVersion";

// Global host configuration
static NSString *_hostVersion = @"1.0.0";
static NSUInteger _protocolVersion = 1;
static NSArray<NSString *> *_availableCapabilities = nil;

// Associated object keys
static const void *PKPlugInInfoBundleKey = &PKPlugInInfoBundleKey;

@implementation PKPlugInInfo (Compatibility)

- (NSBundle *)associatedBundle {
    return objc_getAssociatedObject(self, PKPlugInInfoBundleKey);
}

- (void)setAssociatedBundle:(NSBundle *)bundle {
    objc_setAssociatedObject(self, PKPlugInInfoBundleKey, bundle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)minimumHostVersion {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }
    return [bundle objectForInfoDictionaryKey:PKMinimumHostVersionKey];
}

- (NSString *)maximumHostVersion {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }
    return [bundle objectForInfoDictionaryKey:PKMaximumHostVersionKey];
}

- (NSUInteger)protocolVersion {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }
    NSNumber *version = [bundle objectForInfoDictionaryKey:PKProtocolVersionKey];
    return version ? version.unsignedIntegerValue : 1;
}

- (NSArray<NSString *> *)requiredCapabilities {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }
    NSArray *capabilities = [bundle objectForInfoDictionaryKey:PKRequiredCapabilitiesKey];
    return capabilities ?: @[];
}

- (NSArray<NSString *> *)providedCapabilities {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }
    NSArray *capabilities = [bundle objectForInfoDictionaryKey:PKProvidedCapabilitiesKey];
    return capabilities ?: @[];
}

- (NSArray<PKPlugInDependency *> *)requiredPlugins {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }

    NSArray *rawEntries = [bundle objectForInfoDictionaryKey:PKRequiredPlugInsKey];
    if (![rawEntries isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSMutableArray<PKPlugInDependency *> *dependencies = [NSMutableArray array];
    for (id entry in rawEntries) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        PKPlugInDependency *dependency = [PKPlugInDependency dependencyWithDictionary:entry];
        if (dependency) {
            [dependencies addObject:dependency];
        }
    }
    return [dependencies copy];
}

- (NSString *)deprecatedAtVersion {
    NSBundle *bundle = [self associatedBundle];
    if (!bundle) {
        bundle = [NSBundle bundleWithURL:self.bundleURL];
        [self setAssociatedBundle:bundle];
    }
    NSString *version = [bundle objectForInfoDictionaryKey:PKDeprecatedAtVersionKey];
    return [version isKindOfClass:[NSString class]] ? version : nil;
}

@end

@implementation PKPlugInManager (Compatibility)

+ (NSString *)hostVersion {
    return _hostVersion;
}

+ (void)setHostVersion:(NSString *)version {
    _hostVersion = [version copy];
}

+ (NSUInteger)protocolVersion {
    return _protocolVersion;
}

+ (void)setProtocolVersion:(NSUInteger)version {
    _protocolVersion = version;
}

+ (NSArray<NSString *> *)availableCapabilities {
    if (!_availableCapabilities) {
        // Default capabilities
        return @[@"xpc", @"futures", @"introspection", @"scripting"];
    }
    return _availableCapabilities;
}

+ (void)setAvailableCapabilities:(NSArray<NSString *> *)capabilities {
    _availableCapabilities = [capabilities copy];
}

- (BOOL)isPlugInCompatible:(PKPlugInInfo *)plugIn error:(NSError **)error {
    // Check protocol version
    if (plugIn.protocolVersion != [[self class] protocolVersion]) {
        if (error) {
            NSString *description = [NSString stringWithFormat:
                @"Plugin protocol version %lu does not match host protocol version %lu",
                (unsigned long)plugIn.protocolVersion,
                (unsigned long)[[self class] protocolVersion]];

            *error = [NSError pk_errorWithCode:PKErrorProtocolMismatch
                                   description:description
                                      userInfo:@{
                                          PKErrorPlugInIdentifierKey: plugIn.identifier,
                                          PKErrorRequiredVersionKey: @([[self class] protocolVersion]),
                                          PKErrorActualVersionKey: @(plugIn.protocolVersion)
                                      }];
        }
        return NO;
    }

    // Check minimum host version
    NSString *minimumVersion = plugIn.minimumHostVersion;
    if (minimumVersion) {
        if (![[self class] isVersion:[[self class] hostVersion]
                  compatibleWithMinimum:minimumVersion
                                maximum:nil]) {
            if (error) {
                NSString *description = [NSString stringWithFormat:
                    @"Plugin requires host version %@ or later, but current version is %@",
                    minimumVersion, [[self class] hostVersion]];

                *error = [NSError pk_errorWithCode:PKErrorHostVersionTooOld
                                       description:description
                                          userInfo:@{
                                              PKErrorPlugInIdentifierKey: plugIn.identifier,
                                              PKErrorRequiredVersionKey: minimumVersion,
                                              PKErrorActualVersionKey: [[self class] hostVersion]
                                          }];
            }
            return NO;
        }
    }

    // Check maximum host version
    NSString *maximumVersion = plugIn.maximumHostVersion;
    if (maximumVersion) {
        if (![[self class] isVersion:[[self class] hostVersion]
                  compatibleWithMinimum:nil
                                maximum:maximumVersion]) {
            if (error) {
                NSString *description = [NSString stringWithFormat:
                    @"Plugin requires host version %@ or earlier, but current version is %@",
                    maximumVersion, [[self class] hostVersion]];

                *error = [NSError pk_errorWithCode:PKErrorHostVersionTooNew
                                       description:description
                                          userInfo:@{
                                              PKErrorPlugInIdentifierKey: plugIn.identifier,
                                              PKErrorRequiredVersionKey: maximumVersion,
                                              PKErrorActualVersionKey: [[self class] hostVersion]
                                          }];
            }
            return NO;
        }
    }

    // Check required capabilities
    NSArray<NSString *> *requiredCapabilities = plugIn.requiredCapabilities;
    NSArray<NSString *> *availableCapabilities = [[self class] availableCapabilities];

    for (NSString *required in requiredCapabilities) {
        if (![availableCapabilities containsObject:required]) {
            if (error) {
                NSString *description = [NSString stringWithFormat:
                    @"Plugin requires capability '%@' which is not available", required];

                *error = [NSError pk_errorWithCode:PKErrorMissingCapability
                                       description:description
                                          userInfo:@{
                                              PKErrorPlugInIdentifierKey: plugIn.identifier,
                                              PKErrorMissingCapabilityKey: required
                                          }];
            }
            return NO;
        }
    }

    // Deprecation is advisory: the plugin remains compatible, but the host is
    // warned if it has reached or passed the plugin's deprecation version.
    NSString *deprecatedAtVersion = plugIn.deprecatedAtVersion;
    if (deprecatedAtVersion &&
        [[self class] compareVersion:[[self class] hostVersion]
                           toVersion:deprecatedAtVersion] != NSOrderedAscending) {
        PKLogger *logger = [PKLogger loggerWithCategory:@"Compatibility"];
        [logger warning:@"[%@] Plugin is deprecated as of host version %@ (current host version %@)",
         plugIn.identifier, deprecatedAtVersion, [[self class] hostVersion]];

        id<PKPlugInManagerCompatibilityDelegate> delegate =
            (id<PKPlugInManagerCompatibilityDelegate>)self.delegate;
        if ([delegate respondsToSelector:@selector(plugInManager:didDetectDeprecatedPlugIn:atVersion:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate plugInManager:self didDetectDeprecatedPlugIn:plugIn atVersion:deprecatedAtVersion];
            });
        }
    }

    return YES;
}

+ (BOOL)isVersion:(NSString *)version
compatibleWithMinimum:(NSString *)minimumVersion
          maximum:(NSString *)maximumVersion {

    if (minimumVersion) {
        if ([self compareVersion:version toVersion:minimumVersion] == NSOrderedAscending) {
            return NO;
        }
    }

    if (maximumVersion) {
        if ([self compareVersion:version toVersion:maximumVersion] == NSOrderedDescending) {
            return NO;
        }
    }

    return YES;
}

+ (NSComparisonResult)compareVersion:(NSString *)version1 toVersion:(NSString *)version2 {
    // Parse semantic version strings (e.g., "1.2.3")
    NSArray *components1 = [version1 componentsSeparatedByString:@"."];
    NSArray *components2 = [version2 componentsSeparatedByString:@"."];

    NSInteger maxLength = MAX(components1.count, components2.count);

    for (NSInteger i = 0; i < maxLength; i++) {
        NSInteger value1 = i < components1.count ? [components1[i] integerValue] : 0;
        NSInteger value2 = i < components2.count ? [components2[i] integerValue] : 0;

        if (value1 < value2) {
            return NSOrderedAscending;
        } else if (value1 > value2) {
            return NSOrderedDescending;
        }
    }

    return NSOrderedSame;
}

@end
