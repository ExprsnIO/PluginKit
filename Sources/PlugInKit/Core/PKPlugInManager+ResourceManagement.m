//
//  PKPlugInManager+ResourceManagement.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+ResourceManagement.h"
#import "PKConnection.h"
#import "PKError.h"
#import "PKLogger.h"
#import <objc/runtime.h>
#import <libproc.h>

/// Number of consecutive over-limit samples before a plugin is disconnected.
static const NSUInteger PKResourceMaxConsecutiveBreaches = 3;

@implementation PKResourceLimits

- (instancetype)initWithMemoryLimit:(size_t)memoryLimit cpuLimit:(double)cpuLimit {
    if (self = [super init]) {
        _memoryLimit = memoryLimit;
        _cpuLimit = cpuLimit;
    }
    return self;
}

@end

/// Per-plugin monitoring record.
@interface PKResourceRecord : NSObject
@property (nonatomic, assign) size_t memoryLimit;
@property (nonatomic, assign) double cpuLimit;
@property (nonatomic, assign) uint64_t lastCPUTimeNanos;
@property (nonatomic, assign) NSTimeInterval lastSampleTime;
@property (nonatomic, assign) size_t lastMemory;
@property (nonatomic, assign) double lastCPUPercent;
@property (nonatomic, assign) NSUInteger consecutiveMemoryBreaches;
@property (nonatomic, assign) NSUInteger consecutiveCPUBreaches;
@end

@implementation PKResourceRecord
@end

/// Monitor state held as a single associated object on the manager.
@interface PKResourceMonitorState : NSObject
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PKResourceRecord *> *records;
@property (nonatomic, strong, nullable) dispatch_source_t timer;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) NSTimeInterval interval;
@end

@implementation PKResourceMonitorState

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[NSLock alloc] init];
        _records = [NSMutableDictionary dictionary];
        _queue = dispatch_queue_create("com.pluginkit.manager.resourcemonitor", DISPATCH_QUEUE_SERIAL);
        _interval = 5.0;
    }
    return self;
}

@end

static const void *PKResourceMonitorStateKey = &PKResourceMonitorStateKey;

@implementation PKPlugInManager (ResourceManagement)

- (PKResourceMonitorState *)pk_resourceMonitorState {
    @synchronized (self) {
        PKResourceMonitorState *state = objc_getAssociatedObject(self, PKResourceMonitorStateKey);
        if (!state) {
            state = [[PKResourceMonitorState alloc] init];
            objc_setAssociatedObject(self, PKResourceMonitorStateKey, state,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return state;
    }
}

// MARK: - Configuration

- (NSTimeInterval)resourceMonitoringInterval {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    NSTimeInterval interval = state.interval;
    [state.lock unlock];
    return interval;
}

- (void)setResourceMonitoringInterval:(NSTimeInterval)resourceMonitoringInterval {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    state.interval = MAX(resourceMonitoringInterval, 0.5);
    BOOL running = (state.timer != nil);
    [state.lock unlock];

    if (running) {
        [self pk_stopResourceMonitor];
        [self pk_startResourceMonitor];
    }
}

- (void)setMemoryLimit:(size_t)bytes forPlugIn:(NSString *)identifier {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    PKResourceRecord *record = state.records[identifier];
    if (!record) {
        record = [[PKResourceRecord alloc] init];
        state.records[identifier] = record;
    }
    record.memoryLimit = bytes;
    record.consecutiveMemoryBreaches = 0;
    [state.lock unlock];

    [self pk_startResourceMonitorIfNeeded];
}

- (void)setCPULimit:(double)percentage forPlugIn:(NSString *)identifier {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    PKResourceRecord *record = state.records[identifier];
    if (!record) {
        record = [[PKResourceRecord alloc] init];
        state.records[identifier] = record;
    }
    record.cpuLimit = percentage;
    record.consecutiveCPUBreaches = 0;
    [state.lock unlock];

    [self pk_startResourceMonitorIfNeeded];
}

- (nullable PKResourceLimits *)resourceLimitsForPlugIn:(NSString *)identifier {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    PKResourceRecord *record = state.records[identifier];
    PKResourceLimits *limits = nil;
    if (record && (record.memoryLimit > 0 || record.cpuLimit > 0)) {
        limits = [[PKResourceLimits alloc] initWithMemoryLimit:record.memoryLimit
                                                      cpuLimit:record.cpuLimit];
    }
    [state.lock unlock];
    return limits;
}

- (size_t)memoryUsageForPlugIn:(NSString *)identifier {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    size_t value = state.records[identifier].lastMemory;
    [state.lock unlock];
    return value;
}

- (double)cpuUsageForPlugIn:(NSString *)identifier {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    double value = state.records[identifier].lastCPUPercent;
    [state.lock unlock];
    return value;
}

// MARK: - Monitor Lifecycle

- (void)pk_startResourceMonitorIfNeeded {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    BOOL running = (state.timer != nil);
    BOOL hasRecords = (state.records.count > 0);
    [state.lock unlock];

    if (!running && hasRecords) {
        [self pk_startResourceMonitor];
    }
}

- (void)pk_startResourceMonitor {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    if (state.timer) {
        [state.lock unlock];
        return;
    }

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, state.queue);
    state.timer = timer;
    NSTimeInterval interval = state.interval;
    [state.lock unlock];

    uint64_t intervalNanos = (uint64_t)(interval * NSEC_PER_SEC);
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, intervalNanos),
                              intervalNanos,
                              (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf pk_sampleResourceUsage];
    });

    dispatch_resume(timer);

    [[PKLogger loggerWithCategory:@"ResourceManagement"] debug:@"Resource monitor started (interval %.1fs)", interval];
}

- (void)pk_stopResourceMonitor {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    dispatch_source_t timer = state.timer;
    state.timer = nil;
    [state.lock unlock];

    if (timer) {
        dispatch_source_cancel(timer);
    }
}

// MARK: - Sampling

- (void)pk_sampleResourceUsage {
    PKResourceMonitorState *state = [self pk_resourceMonitorState];

    // Snapshot the identifiers to sample without holding the lock during XPC work.
    [state.lock lock];
    NSArray<NSString *> *identifiers = state.records.allKeys;
    [state.lock unlock];

    for (NSString *identifier in identifiers) {
        PKConnection *connection = [self connectionForPlugIn:identifier];
        if (!connection || connection.state != PKXPCConnectionStateConnected) {
            continue;
        }

        pid_t pid = connection.remoteProcessIdentifier;
        if (pid <= 0) {
            continue;
        }

        struct rusage_info_v4 usage;
        if (proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&usage) != 0) {
            continue;
        }

        size_t memory = (size_t)usage.ri_phys_footprint;
        uint64_t cpuNanos = usage.ri_user_time + usage.ri_system_time;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

        [state.lock lock];
        PKResourceRecord *record = state.records[identifier];
        if (!record) {
            [state.lock unlock];
            continue;
        }

        double cpuPercent = 0.0;
        if (record.lastSampleTime > 0) {
            NSTimeInterval dt = now - record.lastSampleTime;
            if (dt > 0 && cpuNanos >= record.lastCPUTimeNanos) {
                cpuPercent = (double)(cpuNanos - record.lastCPUTimeNanos) / (dt * NSEC_PER_SEC) * 100.0;
            }
        }

        record.lastMemory = memory;
        record.lastCPUTimeNanos = cpuNanos;
        record.lastCPUPercent = cpuPercent;
        BOOL haveCPUSample = (record.lastSampleTime > 0);
        record.lastSampleTime = now;

        size_t memoryLimit = record.memoryLimit;
        double cpuLimit = record.cpuLimit;

        BOOL memoryBreach = (memoryLimit > 0 && memory > memoryLimit);
        record.consecutiveMemoryBreaches = memoryBreach ? record.consecutiveMemoryBreaches + 1 : 0;

        BOOL cpuBreach = (cpuLimit > 0 && haveCPUSample && cpuPercent > cpuLimit);
        record.consecutiveCPUBreaches = cpuBreach ? record.consecutiveCPUBreaches + 1 : 0;

        NSUInteger memoryBreachCount = record.consecutiveMemoryBreaches;
        NSUInteger cpuBreachCount = record.consecutiveCPUBreaches;
        [state.lock unlock];

        [self pk_handleSampleForPlugIn:identifier
                                memory:memory
                           memoryLimit:memoryLimit
                          memoryBreach:memoryBreach
                     memoryBreachCount:memoryBreachCount
                            cpuPercent:cpuPercent
                              cpuLimit:cpuLimit
                             cpuBreach:cpuBreach
                        cpuBreachCount:cpuBreachCount];
    }
}

- (void)pk_handleSampleForPlugIn:(NSString *)identifier
                          memory:(size_t)memory
                     memoryLimit:(size_t)memoryLimit
                    memoryBreach:(BOOL)memoryBreach
               memoryBreachCount:(NSUInteger)memoryBreachCount
                      cpuPercent:(double)cpuPercent
                        cpuLimit:(double)cpuLimit
                       cpuBreach:(BOOL)cpuBreach
                  cpuBreachCount:(NSUInteger)cpuBreachCount {
    PKLogger *logger = [PKLogger loggerWithCategory:@"ResourceManagement"];
    id<PKPlugInManagerResourceDelegate> delegate = self.resourceDelegate;

    if (memoryBreach) {
        [logger warning:@"[%@] Memory limit exceeded: %zu > %zu (%lu consecutive)",
         identifier, memory, memoryLimit, (unsigned long)memoryBreachCount];

        if ([delegate respondsToSelector:@selector(plugInManager:plugIn:didExceedMemoryLimit:current:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate plugInManager:self plugIn:identifier didExceedMemoryLimit:memoryLimit current:memory];
            });
        }

        if (memoryBreachCount >= PKResourceMaxConsecutiveBreaches) {
            NSError *error = [NSError pk_errorWithCode:PKErrorMemoryLimitExceeded
                                           description:@"Plugin disconnected for sustained memory limit violation"
                                              userInfo:@{PKErrorPlugInIdentifierKey: identifier}];
            [self pk_disconnectPlugIn:identifier forResourceViolation:error];
            return;
        }
    }

    if (cpuBreach) {
        [logger warning:@"[%@] CPU limit exceeded: %.1f%% > %.1f%% (%lu consecutive)",
         identifier, cpuPercent, cpuLimit, (unsigned long)cpuBreachCount];

        if ([delegate respondsToSelector:@selector(plugInManager:plugIn:didExceedCPULimit:current:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate plugInManager:self plugIn:identifier didExceedCPULimit:cpuLimit current:cpuPercent];
            });
        }

        if (cpuBreachCount >= PKResourceMaxConsecutiveBreaches) {
            NSError *error = [NSError pk_errorWithCode:PKErrorCPULimitExceeded
                                           description:@"Plugin disconnected for sustained CPU limit violation"
                                              userInfo:@{PKErrorPlugInIdentifierKey: identifier}];
            [self pk_disconnectPlugIn:identifier forResourceViolation:error];
        }
    }
}

- (void)pk_disconnectPlugIn:(NSString *)identifier forResourceViolation:(NSError *)error {
    PKLogger *logger = [PKLogger loggerWithCategory:@"ResourceManagement"];
    [logger error:@"[%@] Disconnecting plugin: %@", identifier, error.localizedDescription];

    // Reset breach counters so a future reconnection starts fresh.
    PKResourceMonitorState *state = [self pk_resourceMonitorState];
    [state.lock lock];
    PKResourceRecord *record = state.records[identifier];
    record.consecutiveMemoryBreaches = 0;
    record.consecutiveCPUBreaches = 0;
    [state.lock unlock];

    [self disconnectFromPlugIn:identifier];

    id<PKPlugInManagerResourceDelegate> delegate = self.resourceDelegate;
    if ([delegate respondsToSelector:@selector(plugInManager:didDisconnectPlugInForResourceViolation:error:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate plugInManager:self didDisconnectPlugInForResourceViolation:identifier error:error];
        });
    }
}

@end
