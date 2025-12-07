//
//  PKHostProtocol.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Protocol that host applications implement for bidirectional communication
@protocol PKHostProtocol <NSObject>

@required

/// Plugin sends notification to host
/// @param notification Notification dictionary
/// @param plugInIdentifier Identifier of the sending plugin
/// @param reply Completion handler
- (void)didReceiveNotification:(NSDictionary<NSString *, id> *)notification
              fromPlugIn:(NSString *)plugInIdentifier
                   reply:(void (^)(BOOL acknowledged))reply;

@optional

/// Plugin requests permission for an operation
/// @param operation Operation identifier
/// @param context Additional context for the request
/// @param plugInIdentifier Identifier of the requesting plugin
/// @param reply Completion handler with permission result
- (void)requestPermissionForOperation:(NSString *)operation
                              context:(nullable NSDictionary<NSString *, id> *)context
                           fromPlugIn:(NSString *)plugInIdentifier
                                reply:(void (^)(BOOL granted, NSError * _Nullable error))reply;

/// Plugin requests data from host
/// @param dataType Type of data requested
/// @param parameters Request parameters
/// @param plugInIdentifier Identifier of the requesting plugin
/// @param reply Completion handler with requested data
- (void)requestDataOfType:(NSString *)dataType
               parameters:(nullable NSDictionary<NSString *, id> *)parameters
               fromPlugIn:(NSString *)plugInIdentifier
                    reply:(void (^)(id _Nullable data, NSError * _Nullable error))reply;

/// Host updates its state and notifies plugin
/// @param state Current state dictionary
- (void)updateHostState:(NSDictionary<NSString *, id> *)state;

@end

NS_ASSUME_NONNULL_END
