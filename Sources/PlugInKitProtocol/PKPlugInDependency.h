//
//  PKPlugInDependency.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Describes a single plugin-to-plugin dependency.
///
/// Declared in a plugin's Info.plist under the `PKRequiredPlugins` key as an
/// array of dictionaries, each with keys: `identifier` (required, string),
/// `minimumVersion` (optional, string), `maximumVersion` (optional, string),
/// and `optional` (optional, boolean — default NO).
///
/// Dependencies are used for connection ordering only: a dependency must be
/// connected before its dependent. They do not establish a shared transport or
/// direct plugin-to-plugin messaging channel.
@interface PKPlugInDependency : NSObject <NSSecureCoding>

/// Identifier of the required plugin.
@property (nonatomic, copy, readonly) NSString *identifier;

/// Minimum acceptable version of the dependency, or nil for no minimum.
@property (nonatomic, copy, readonly, nullable) NSString *minimumVersion;

/// Maximum acceptable version of the dependency, or nil for no maximum.
@property (nonatomic, copy, readonly, nullable) NSString *maximumVersion;

/// Whether the dependency is optional. An optional dependency that is missing
/// is skipped; a required dependency that is missing fails resolution.
@property (nonatomic, assign, readonly, getter=isOptional) BOOL optional;

- (instancetype)initWithIdentifier:(NSString *)identifier
                    minimumVersion:(nullable NSString *)minimumVersion
                    maximumVersion:(nullable NSString *)maximumVersion
                          optional:(BOOL)optional NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Parse a dependency from an Info.plist dictionary entry.
/// @param dictionary Dictionary with at least an `identifier` key
/// @return A dependency, or nil if the dictionary lacks a valid identifier
+ (nullable instancetype)dependencyWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
