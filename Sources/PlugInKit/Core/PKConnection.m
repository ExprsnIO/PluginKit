//
//  PKConnection.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKConnection.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"

static const NSUInteger kPKConnectionLatencySampleSize = 10;

@interface PKConnection () <PKXPCServiceDelegate>

@property (nonatomic, strong) PKXPCService *xpcService;
@property (nonatomic, copy, readwrite) NSString *plugInIdentifier;
@property (nonatomic, assign, readwrite) PKConnectionHealth health;
@property (nonatomic, assign, readwrite) PKXPCConnectionState state;
@property (nonatomic, strong) dispatch_source_t pollTimer;
@property (nonatomic, strong) dispatch_queue_t pollQueue;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *latencySamples;
@property (nonatomic, assign, readwrite) NSTimeInterval averageLatency;
@property (nonatomic, assign) NSUInteger consecutiveFailures;

@end

@implementation PKConnection

- (instancetype)initWithPlugInIdentifier:(NSString *)plugInIdentifier
                             serviceName:(NSString *)serviceName
                               interface:(NSXPCInterface *)interface {
    if (self = [super init]) {
        _plugInIdentifier = [plugInIdentifier copy];
        _health = PKConnectionHealthUnknown;
        _state = PKXPCConnectionStateDisconnected;
        _pollingInterval = 5.0;
        _degradedLatencyThreshold = 1.0;
        _unhealthyLatencyThreshold = 3.0;
        _latencySamples = [NSMutableArray arrayWithCapacity:kPKConnectionLatencySampleSize];
        _pollQueue = dispatch_queue_create("com.pluginkit.connection.poll", DISPATCH_QUEUE_SERIAL);

        _xpcService = [[PKXPCService alloc] initWithServiceName:serviceName
                                                      interface:interface
                                                          queue:dispatch_get_main_queue()];
        _xpcService.delegate = self;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)start {
    [self.xpcService activate];

    if (self.isPollingEnabled) {
        [self startPolling];
    }
}

- (void)stop {
    [self stopPolling];
    [self.xpcService cancel];
}

- (void)setPollingEnabled:(BOOL)pollingEnabled {
    if (_pollingEnabled != pollingEnabled) {
        _pollingEnabled = pollingEnabled;

        if (pollingEnabled && self.state == PKXPCConnectionStateConnected) {
            [self startPolling];
        } else if (!pollingEnabled) {
            [self stopPolling];
        }
    }
}

- (void)startPolling {
    [self stopPolling];

    dispatch_queue_t queue = self.pollQueue;
    self.pollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    if (!self.pollTimer) {
        return;
    }

    uint64_t interval = (uint64_t)(self.pollingInterval * NSEC_PER_SEC);
    dispatch_source_set_timer(self.pollTimer,
                             dispatch_time(DISPATCH_TIME_NOW, interval),
                             interval,
                             (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.pollTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf performPoll];
        }
    });

    dispatch_resume(self.pollTimer);
}

- (void)stopPolling {
    if (self.pollTimer) {
        dispatch_source_cancel(self.pollTimer);
        self.pollTimer = nil;
    }
}

- (void)performPoll {
    [self pollWithCompletion:^(BOOL success, NSTimeInterval latency, NSError * _Nullable error) {
        // Completion handler for internal polling
        // Delegate is already notified in pollWithCompletion:
    }];
}

- (void)pollWithCompletion:(void (^)(BOOL success, NSTimeInterval latency, NSError * _Nullable error))completion {
    NSDate *startDate = [NSDate date];

    id<PKPlugInProtocol> plugin = [self remotePlugInWithErrorHandler:^(NSError *error) {
        NSTimeInterval latency = [[NSDate date] timeIntervalSinceDate:startDate];

        self.consecutiveFailures++;
        [self updateHealthWithLatency:latency success:NO];

        if ([self.delegate respondsToSelector:@selector(connection:didCompletePoll:latency:)]) {
            [self.delegate connection:self didCompletePoll:NO latency:latency];
        }

        if (completion) {
            completion(NO, latency, error);
        }
    }];

    // Simple ping by requesting capabilities
    if ([plugin respondsToSelector:@selector(capabilitiesWithReply:)]) {
        [plugin capabilitiesWithReply:^(NSDictionary<NSString *,id> * _Nonnull capabilities) {
            NSTimeInterval latency = [[NSDate date] timeIntervalSinceDate:startDate];

            self.consecutiveFailures = 0;
            [self updateHealthWithLatency:latency success:YES];

            if ([self.delegate respondsToSelector:@selector(connection:didCompletePoll:latency:)]) {
                [self.delegate connection:self didCompletePoll:YES latency:latency];
            }

            if (completion) {
                completion(YES, latency, nil);
            }
        }];
    } else {
        // Fallback: use exposedMethods as ping
        [plugin exposedMethodsWithReply:^(NSArray<PKMethodMetadata *> * _Nonnull methods) {
            NSTimeInterval latency = [[NSDate date] timeIntervalSinceDate:startDate];

            self.consecutiveFailures = 0;
            [self updateHealthWithLatency:latency success:YES];

            if ([self.delegate respondsToSelector:@selector(connection:didCompletePoll:latency:)]) {
                [self.delegate connection:self didCompletePoll:YES latency:latency];
            }

            if (completion) {
                completion(YES, latency, nil);
            }
        }];
    }
}

- (void)updateHealthWithLatency:(NSTimeInterval)latency success:(BOOL)success {
    // Update latency samples
    @synchronized (self.latencySamples) {
        [self.latencySamples addObject:@(latency)];
        if (self.latencySamples.count > kPKConnectionLatencySampleSize) {
            [self.latencySamples removeObjectAtIndex:0];
        }

        // Calculate average
        double sum = 0;
        for (NSNumber *sample in self.latencySamples) {
            sum += sample.doubleValue;
        }
        self.averageLatency = sum / self.latencySamples.count;
    }

    // Determine health
    PKConnectionHealth newHealth;

    if (!success || self.consecutiveFailures >= 3) {
        newHealth = PKConnectionHealthUnhealthy;
    } else if (self.averageLatency > self.unhealthyLatencyThreshold) {
        newHealth = PKConnectionHealthUnhealthy;
    } else if (self.averageLatency > self.degradedLatencyThreshold || self.consecutiveFailures > 0) {
        newHealth = PKConnectionHealthDegraded;
    } else {
        newHealth = PKConnectionHealthHealthy;
    }

    if (self.health != newHealth) {
        self.health = newHealth;

        if ([self.delegate respondsToSelector:@selector(connection:didChangeHealth:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate connection:self didChangeHealth:newHealth];
            });
        }
    }
}

- (id<PKPlugInProtocol>)remotePlugInWithErrorHandler:(void (^)(NSError *error))errorHandler {
    return (id<PKPlugInProtocol>)[self.xpcService remoteObjectProxyWithErrorHandler:errorHandler];
}

- (id<PKPlugInProtocol>)synchronousRemotePlugInWithErrorHandler:(void (^)(NSError *error))errorHandler {
    return (id<PKPlugInProtocol>)[self.xpcService synchronousRemoteObjectProxyWithErrorHandler:errorHandler];
}

#pragma mark - PKXPCServiceDelegate

- (void)xpcService:(PKXPCService *)service didChangeState:(PKXPCConnectionState)state {
    self.state = state;

    if ([self.delegate respondsToSelector:@selector(connection:didChangeState:)]) {
        [self.delegate connection:self didChangeState:state];
    }

    // Start polling when connected
    if (state == PKXPCConnectionStateConnected && self.isPollingEnabled) {
        [self startPolling];
    } else {
        [self stopPolling];
    }
}

- (void)xpcServiceDidInterrupt:(PKXPCService *)service {
    self.health = PKConnectionHealthUnhealthy;
    self.consecutiveFailures++;

    if ([self.delegate respondsToSelector:@selector(connection:didChangeHealth:)]) {
        [self.delegate connection:self didChangeHealth:self.health];
    }
}

- (void)xpcServiceDidInvalidate:(PKXPCService *)service {
    [self stopPolling];
    self.health = PKConnectionHealthUnhealthy;

    if ([self.delegate respondsToSelector:@selector(connection:didChangeHealth:)]) {
        [self.delegate connection:self didChangeHealth:self.health];
    }
}

@end
