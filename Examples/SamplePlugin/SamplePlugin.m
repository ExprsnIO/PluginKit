//
//  SamplePlugin.m
//  SamplePlugin
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "SamplePlugin.h"

@interface SamplePlugin ()

@property (nonatomic, copy) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, copy) NSString *plugInIdentifier;
@property (nonatomic, copy) NSString *plugInVersion;
@property (nonatomic, copy) NSString *plugInDisplayName;

@end

@implementation SamplePlugin

- (instancetype)init {
    if (self = [super init]) {
        _plugInIdentifier = @"com.example.sampleplugin";
        _plugInVersion = @"1.0.0";
        _plugInDisplayName = @"Sample Plugin";
    }
    return self;
}

#pragma mark - PKPlugInProtocol

- (void)initializeWithConfiguration:(NSDictionary<NSString *,id> *)configuration
                              reply:(void (^)(NSError * _Nullable))reply {
    NSLog(@"[SamplePlugin] Initializing with configuration: %@", configuration);
    self.configuration = configuration;

    // Simulate async initialization
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        reply(nil);
    });
}

- (void)prepareForTerminationWithReply:(void (^)(void))reply {
    NSLog(@"[SamplePlugin] Preparing for termination");

    // Cleanup tasks
    self.configuration = nil;

    reply();
}

- (void)exposedMethodsWithReply:(void (^)(NSArray<PKMethodMetadata *> * _Nonnull))reply {
    NSMutableArray<PKMethodMetadata *> *methods = [NSMutableArray array];

    // Method 1: Process data
    PKMethodMetadata *processData = [[PKMethodMetadata alloc]
        initWithSelector:@"processData:withOptions:reply:"
        displayName:@"Process Data"
        description:@"Processes input data with specified options"
        exposureOptions:PKMethodExposureAll
        parameterTypes:@[@"@\"NSString\"", @"@\"NSDictionary\""]
        returnType:@"@\"NSString\""];
    [methods addObject:processData];

    // Method 2: Calculate
    PKMethodMetadata *calculate = [[PKMethodMetadata alloc]
        initWithSelector:@"calculateValue:reply:"
        displayName:@"Calculate Value"
        description:@"Performs a calculation on the input value"
        exposureOptions:PKMethodExposureAppleScript
        parameterTypes:@[@"d"]
        returnType:@"d"];
    [methods addObject:calculate];

    // Method 3: Get status (exposed to JavaScript only)
    PKMethodMetadata *getStatus = [[PKMethodMetadata alloc]
        initWithSelector:@"getStatusWithReply:"
        displayName:@"Get Status"
        description:@"Returns the current plugin status"
        exposureOptions:PKMethodExposureJavaScript
        parameterTypes:@[]
        returnType:@"@\"NSDictionary\""];
    [methods addObject:getStatus];

    // Method 4: Internal method (not exposed)
    PKMethodMetadata *internalMethod = [[PKMethodMetadata alloc]
        initWithSelector:@"internalProcessingWithReply:"
        displayName:@"Internal Processing"
        description:@"Internal method not exposed to scripting"
        exposureOptions:PKMethodExposureNone
        parameterTypes:@[]
        returnType:@"v"];
    [methods addObject:internalMethod];

    reply([methods copy]);
}

- (void)handleMessage:(NSDictionary<NSString *,id> *)message
                reply:(void (^)(NSDictionary<NSString *,id> * _Nullable, NSError * _Nullable))reply {
    NSLog(@"[SamplePlugin] Received message: %@", message);

    NSString *action = message[@"action"];

    if ([action isEqualToString:@"echo"]) {
        NSDictionary *response = @{
            @"status": @"success",
            @"echo": message[@"data"] ?: @"",
            @"timestamp": [NSDate date]
        };
        reply(response, nil);
    } else {
        NSError *error = [NSError errorWithDomain:@"com.example.sampleplugin"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unknown action"}];
        reply(nil, error);
    }
}

- (void)hostStateDidChange:(NSDictionary<NSString *,id> *)state {
    NSLog(@"[SamplePlugin] Host state changed: %@", state);
}

- (void)capabilitiesWithReply:(void (^)(NSDictionary<NSString *,id> * _Nonnull))reply {
    NSDictionary *capabilities = @{
        @"supportsDataProcessing": @YES,
        @"supportsCalculation": @YES,
        @"version": self.plugInVersion,
        @"features": @[@"echo", @"process", @"calculate"]
    };

    reply(capabilities);
}

#pragma mark - Plugin Methods (Examples)

- (void)processData:(NSString *)data
        withOptions:(NSDictionary *)options
              reply:(void (^)(NSString *result))reply {
    NSLog(@"[SamplePlugin] Processing data: %@ with options: %@", data, options);

    // Simulate processing
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *result = [NSString stringWithFormat:@"Processed: %@", data.uppercaseString];
        reply(result);
    });
}

- (void)calculateValue:(double)value reply:(void (^)(double result))reply {
    NSLog(@"[SamplePlugin] Calculating value: %f", value);

    // Simple calculation
    double result = value * 2.0 + 10.0;
    reply(result);
}

- (void)getStatusWithReply:(void (^)(NSDictionary *status))reply {
    NSDictionary *status = @{
        @"state": @"running",
        @"uptime": @(120.5),
        @"lastActivity": [NSDate date]
    };

    reply(status);
}

- (void)internalProcessingWithReply:(void (^)(void))reply {
    NSLog(@"[SamplePlugin] Internal processing");
    // Internal work
    reply();
}

@end
