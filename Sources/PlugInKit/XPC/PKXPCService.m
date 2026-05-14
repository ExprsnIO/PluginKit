//
//  PKXPCService.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKXPCService.h"

@interface PKXPCService ()

@property (nonatomic, strong) NSXPCConnection *connection;
@property (nonatomic, strong) NSXPCInterface *remoteInterface;
@property (nonatomic, assign, readwrite) PKXPCConnectionState state;
@property (nonatomic, copy, readwrite) NSString *serviceName;
@property (nonatomic, strong, readwrite) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_queue_t internalQueue;

@end

@implementation PKXPCService

- (instancetype)initWithServiceName:(NSString *)serviceName
                          interface:(NSXPCInterface *)interface
                              queue:(nullable dispatch_queue_t)queue {
    if (self = [super init]) {
        _serviceName = [serviceName copy];
        _remoteInterface = interface;
        _delegateQueue = queue ?: dispatch_get_main_queue();
        _internalQueue = dispatch_queue_create("com.pluginkit.xpcservice.internal", DISPATCH_QUEUE_SERIAL);
        _state = PKXPCConnectionStateDisconnected;
    }
    return self;
}

- (void)dealloc {
    [self cancel];
}

- (void)activate {
    dispatch_async(self.internalQueue, ^{
        if (self.state != PKXPCConnectionStateDisconnected) {
            return;
        }

        [self setState:PKXPCConnectionStateConnecting];

        self.connection = [[NSXPCConnection alloc] initWithServiceName:self.serviceName];
        self.connection.remoteObjectInterface = self.remoteInterface;

        __weak typeof(self) weakSelf = self;

        self.connection.interruptionHandler = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            dispatch_async(strongSelf.internalQueue, ^{
                [strongSelf setState:PKXPCConnectionStateInterrupted];

                dispatch_async(strongSelf.delegateQueue, ^{
                    if ([strongSelf.delegate respondsToSelector:@selector(xpcServiceDidInterrupt:)]) {
                        [strongSelf.delegate xpcServiceDidInterrupt:strongSelf];
                    }
                });
            });
        };

        self.connection.invalidationHandler = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            dispatch_async(strongSelf.internalQueue, ^{
                [strongSelf setState:PKXPCConnectionStateInvalidated];

                dispatch_async(strongSelf.delegateQueue, ^{
                    if ([strongSelf.delegate respondsToSelector:@selector(xpcServiceDidInvalidate:)]) {
                        [strongSelf.delegate xpcServiceDidInvalidate:strongSelf];
                    }
                });
            });
        };

        [self.connection resume];
        [self setState:PKXPCConnectionStateConnected];
    });
}

- (void)cancel {
    dispatch_async(self.internalQueue, ^{
        if (self.connection) {
            [self.connection invalidate];
            self.connection = nil;
        }
        [self setState:PKXPCConnectionStateInvalidated];
    });
}

- (void)setState:(PKXPCConnectionState)state {
    if (_state != state) {
        _state = state;

        __weak typeof(self) weakSelf = self;
        dispatch_async(self.delegateQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(xpcService:didChangeState:)]) {
                [strongSelf.delegate xpcService:strongSelf didChangeState:state];
            }
        });
    }
}

- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *error))errorHandler {
    __block id proxy = nil;
    dispatch_sync(self.internalQueue, ^{
        proxy = [self.connection remoteObjectProxyWithErrorHandler:errorHandler];
    });
    return proxy;
}

- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError *error))errorHandler {
    __block id proxy = nil;
    dispatch_sync(self.internalQueue, ^{
        proxy = [self.connection synchronousRemoteObjectProxyWithErrorHandler:errorHandler];
    });
    return proxy;
}

- (pid_t)remoteProcessIdentifier {
    __block pid_t pid = 0;
    dispatch_sync(self.internalQueue, ^{
        if (self.connection) {
            pid = self.connection.processIdentifier;
        }
    });
    return pid;
}

- (void)exportObject:(id)object withInterface:(NSXPCInterface *)interface {
    dispatch_async(self.internalQueue, ^{
        if (self.connection) {
            self.connection.exportedInterface = interface;
            self.connection.exportedObject = object;
        }
    });
}

@end
