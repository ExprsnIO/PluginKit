//
//  PKPlugInState.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// NSSecureCoding-compliant envelope for plugin state transferred across XPC.
///
/// Used by hot-reload state migration and lifecycle save/restore. The envelope
/// carries identifying metadata alongside an opaque, secure-coded payload so the
/// host can validate that restored state belongs to the expected plugin/version.
@interface PKPlugInState : NSObject <NSSecureCoding>

/// Identifier of the plugin this state belongs to.
@property (nonatomic, copy, readonly) NSString *identifier;

/// Version of the plugin that produced this state.
@property (nonatomic, copy, readonly) NSString *version;

/// Timestamp at which the state was captured.
@property (nonatomic, copy, readonly) NSDate *capturedAt;

/// Opaque plugin-defined state payload. All values must conform to NSSecureCoding.
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id<NSSecureCoding>> *payload;

/// Create a state envelope.
/// @param identifier Plugin identifier
/// @param version Plugin version
/// @param payload Plugin-defined state payload (NSSecureCoding values)
- (instancetype)initWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                           payload:(NSDictionary<NSString *, id<NSSecureCoding>> *)payload;

@end

NS_ASSUME_NONNULL_END
