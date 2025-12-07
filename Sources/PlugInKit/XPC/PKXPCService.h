//
//  PKXPCService.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PKXPCService;

/// Connection state for XPC services
typedef NS_ENUM(NSInteger, PKXPCConnectionState) {
    PKXPCConnectionStateDisconnected,
    PKXPCConnectionStateConnecting,
    PKXPCConnectionStateConnected,
    PKXPCConnectionStateInterrupted,
    PKXPCConnectionStateInvalidated
};

/// Delegate protocol for XPC service events
@protocol PKXPCServiceDelegate <NSObject>

@optional

/// Called when connection state changes
/// @param service The XPC service
/// @param state New connection state
- (void)xpcService:(PKXPCService *)service didChangeState:(PKXPCConnectionState)state;

/// Called when connection is interrupted
/// @param service The XPC service
- (void)xpcServiceDidInterrupt:(PKXPCService *)service;

/// Called when connection is invalidated
/// @param service The XPC service
- (void)xpcServiceDidInvalidate:(PKXPCService *)service;

@end

/// Modern XPC service wrapper with Network.framework-inspired API
@interface PKXPCService : NSObject

/// Current connection state
@property (nonatomic, assign, readonly) PKXPCConnectionState state;

/// Service name
@property (nonatomic, copy, readonly) NSString *serviceName;

/// Delegate for service events
@property (nonatomic, weak, nullable) id<PKXPCServiceDelegate> delegate;

/// Dispatch queue for delegate callbacks
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;

/// Create a new XPC service
/// @param serviceName Name of the XPC service
/// @param interface Remote object interface
/// @param queue Dispatch queue for callbacks
- (instancetype)initWithServiceName:(NSString *)serviceName
                          interface:(NSXPCInterface *)interface
                              queue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Activate the service connection
- (void)activate;

/// Cancel the service connection
- (void)cancel;

/// Get the remote object proxy
/// @param errorHandler Error handler for connection failures
/// @return Remote object proxy
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *error))errorHandler;

/// Get the synchronous remote object proxy
/// @param errorHandler Error handler for connection failures
/// @return Synchronous remote object proxy
- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *error))errorHandler;

/// Export an object to the remote side
/// @param object Object to export
/// @param interface Interface for the exported object
- (void)exportObject:(id)object withInterface:(NSXPCInterface *)interface;

@end

NS_ASSUME_NONNULL_END
