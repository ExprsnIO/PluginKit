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

@end

NS_ASSUME_NONNULL_END
