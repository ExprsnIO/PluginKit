//
//  PKPlugInManager+Compatibility.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKPlugInManager.h"

@class PKPlugInDependency;

NS_ASSUME_NONNULL_BEGIN

/// Extended plugin information with versioning
@interface PKPlugInInfo (Compatibility)

/// Minimum required host version
@property (nonatomic, copy, readonly, nullable) NSString *minimumHostVersion;

/// Maximum supported host version
@property (nonatomic, copy, readonly, nullable) NSString *maximumHostVersion;

/// Plugin protocol version number
@property (nonatomic, assign, readonly) NSUInteger protocolVersion;

/// Required capabilities from host
@property (nonatomic, copy, readonly) NSArray<NSString *> *requiredCapabilities;

/// Optional capabilities provided by plugin
@property (nonatomic, copy, readonly) NSArray<NSString *> *providedCapabilities;

/// Other plugins this plugin depends on (Info.plist key `PKRequiredPlugins`).
@property (nonatomic, copy, readonly) NSArray<PKPlugInDependency *> *requiredPlugins;

/// Host version at which this plugin becomes deprecated (Info.plist key
/// `PKDeprecatedAtVersion`), or nil if the plugin is not deprecated.
@property (nonatomic, copy, readonly, nullable) NSString *deprecatedAtVersion;

@end

/// Compatibility checking for plugin manager
@interface PKPlugInManager (Compatibility)

/// Current host version string
@property (class, nonatomic, copy, readonly) NSString *hostVersion;

/// Current protocol version
@property (class, nonatomic, assign, readonly) NSUInteger protocolVersion;

/// Available host capabilities
@property (class, nonatomic, copy, readonly) NSArray<NSString *> *availableCapabilities;

/// Set the host version (call once at initialization)
/// @param version Version string (e.g., "1.0.0")
+ (void)setHostVersion:(NSString *)version;

/// Set the protocol version
/// @param version Protocol version number
+ (void)setProtocolVersion:(NSUInteger)version;

/// Set available capabilities
/// @param capabilities Array of capability strings
+ (void)setAvailableCapabilities:(NSArray<NSString *> *)capabilities;

/// Check if a plugin is compatible with the current host
/// @param plugIn Plugin info to check
/// @param error Error output if incompatible
/// @return YES if compatible
- (BOOL)isPlugInCompatible:(PKPlugInInfo *)plugIn error:(NSError **)error;

/// Check if a specific version is compatible
/// @param version Version string to check
/// @param minimumVersion Minimum required version
/// @param maximumVersion Maximum allowed version (nil = no maximum)
/// @return YES if compatible
+ (BOOL)isVersion:(NSString *)version
compatibleWithMinimum:(nullable NSString *)minimumVersion
          maximum:(nullable NSString *)maximumVersion;

/// Compare two version strings
/// @param version1 First version
/// @param version2 Second version
/// @return NSComparisonResult
+ (NSComparisonResult)compareVersion:(NSString *)version1 toVersion:(NSString *)version2;

@end

/// Delegate protocol for compatibility notifications
@protocol PKPlugInManagerCompatibilityDelegate <NSObject>

@optional

/// Called when an incompatible plugin is discovered
/// @param manager Plugin manager
/// @param plugIn Incompatible plugin info
/// @param reason Human-readable reason for incompatibility
- (void)plugInManager:(PKPlugInManager *)manager
didRejectIncompatiblePlugIn:(PKPlugInInfo *)plugIn
               reason:(NSString *)reason;

/// Called when a compatible but deprecated plugin is detected. The plugin is
/// still considered compatible; this is an advisory notification.
/// @param manager Plugin manager
/// @param plugIn The deprecated plugin
/// @param version Host version at which the plugin became deprecated
- (void)plugInManager:(PKPlugInManager *)manager
didDetectDeprecatedPlugIn:(PKPlugInInfo *)plugIn
            atVersion:(NSString *)version;

@end

NS_ASSUME_NONNULL_END
