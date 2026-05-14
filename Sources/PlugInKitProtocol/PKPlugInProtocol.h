//
//  PKPlugInProtocol.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Options for method exposure in scripting environments
typedef NS_OPTIONS(NSUInteger, PKMethodExposureOptions) {
    PKMethodExposureNone        = 0,
    PKMethodExposureAppleScript = 1 << 0,
    PKMethodExposureJavaScript  = 1 << 1,
    PKMethodExposureAll         = PKMethodExposureAppleScript | PKMethodExposureJavaScript
};

/// Metadata for plugin methods
@interface PKMethodMetadata : NSObject <NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *selector;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, nullable, readonly) NSString *methodDescription;
@property (nonatomic, assign, readonly) PKMethodExposureOptions exposureOptions;
@property (nonatomic, copy, readonly) NSArray<NSString *> *parameterTypes;
@property (nonatomic, copy, readonly) NSString *returnType;

- (instancetype)initWithSelector:(NSString *)selector
                     displayName:(NSString *)displayName
                     description:(nullable NSString *)description
                exposureOptions:(PKMethodExposureOptions)options
                  parameterTypes:(NSArray<NSString *> *)parameterTypes
                      returnType:(NSString *)returnType;

@end

/// Protocol that all plugins must implement
@protocol PKPlugInProtocol <NSObject>

@required

/// Initialize the plugin with configuration
/// @param configuration Dictionary containing plugin-specific configuration
/// @param reply Completion handler called when initialization completes
- (void)initializeWithConfiguration:(NSDictionary<NSString *, id> *)configuration
                              reply:(void (^)(NSError * _Nullable error))reply;

/// Called when the plugin should prepare to terminate
/// @param reply Completion handler called when cleanup is complete
- (void)prepareForTerminationWithReply:(void (^)(void))reply;

/// Retrieve metadata for all exposed methods
/// @param reply Completion handler returning array of method metadata
- (void)exposedMethodsWithReply:(void (^)(NSArray<PKMethodMetadata *> *methods))reply;

@optional

/// Plugin identifier
@property (nonatomic, copy, readonly) NSString *plugInIdentifier;

/// Plugin version
@property (nonatomic, copy, readonly) NSString *plugInVersion;

/// Plugin display name
@property (nonatomic, copy, readonly) NSString *plugInDisplayName;

/// Handle custom messages from the host
/// @param message Message dictionary
/// @param reply Completion handler with response
- (void)handleMessage:(NSDictionary<NSString *, id> *)message
                reply:(void (^)(NSDictionary<NSString *, id> * _Nullable response, NSError * _Nullable error))reply;

/// Notification that the host state changed
/// @param state New state dictionary
- (void)hostStateDidChange:(NSDictionary<NSString *, id> *)state;

/// Request for plugin-specific capabilities
/// @param reply Completion handler returning capabilities dictionary
- (void)capabilitiesWithReply:(void (^)(NSDictionary<NSString *, id> *capabilities))reply;

// MARK: - Lifecycle Hooks

/// Called immediately before the plugin connection is fully established,
/// after the XPC connection is up but before `initializeWithConfiguration:reply:`.
/// @param reply Completion handler called when the plugin is ready to load
- (void)willLoadWithReply:(void (^)(NSError * _Nullable error))reply;

/// Called after the plugin has been initialized and the connection is established.
/// @param reply Completion handler called when post-load setup is complete
- (void)didLoadWithReply:(void (^)(NSError * _Nullable error))reply;

/// Called before the plugin connection is torn down, before
/// `prepareForTerminationWithReply:`.
/// @param reply Completion handler called when the plugin is ready to unload
- (void)willUnloadWithReply:(void (^)(NSError * _Nullable error))reply;

/// Called after the plugin connection has been torn down.
/// @param reply Completion handler called when post-unload cleanup is complete
- (void)didUnloadWithReply:(void (^)(NSError * _Nullable error))reply;

/// Called when the host suspends the plugin. The plugin should pause work and
/// release transient resources; it will not receive messages while suspended.
/// @param reply Completion handler called when the plugin has suspended
- (void)willSuspendWithReply:(void (^)(NSError * _Nullable error))reply;

/// Called when the host resumes a previously suspended plugin.
/// @param reply Completion handler called when the plugin has resumed
- (void)didResumeWithReply:(void (^)(NSError * _Nullable error))reply;

@end

NS_ASSUME_NONNULL_END
