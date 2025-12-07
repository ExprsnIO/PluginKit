//
//  FuturesExample.m
//  PlugInKit Futures Example
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PlugInKit/PlugInKit.h>

@interface FuturesExample : NSObject
@end

@implementation FuturesExample

- (void)demonstrateBasicFutures {
    NSLog(@"\n=== Basic Futures ===\n");

    // 1. Create a simple future
    PKFuture *simple = [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            fulfill(@"Hello, Futures!");
        });
    }];

    [simple onSuccess:^(id _Nullable value) {
        NSLog(@"Simple future resolved: %@", value);
    }];

    // 2. Immediately fulfilled
    PKFuture *immediate = [PKFuture fulfilledWithValue:@42];
    NSLog(@"Immediate value: %@", [immediate wait]);

    // 3. Immediately rejected
    NSError *error = [NSError errorWithDomain:@"example" code:1 userInfo:nil];
    PKFuture *failed = [PKFuture rejectedWithError:error];

    [failed onFailure:^(NSError *err) {
        NSLog(@"Future failed as expected: %@", err);
    }];
}

- (void)demonstrateChaining {
    NSLog(@"\n=== Future Chaining ===\n");

    // Chain with then
    PKFuture *chain = [PKFuture fulfilledWithValue:@10];

    PKFuture *result = [[[[chain
        then:^id _Nullable(id _Nullable value) {
            NSLog(@"Step 1: %@", value);
            return @([value integerValue] * 2); // 20
        }]
        then:^id _Nullable(id _Nullable value) {
            NSLog(@"Step 2: %@", value);
            return @([value integerValue] + 5); // 25
        }]
        then:^id _Nullable(id _Nullable value) {
            NSLog(@"Step 3: %@", value);
            return [NSString stringWithFormat:@"Result: %@", value];
        }]
        onSuccess:^(id _Nullable value) {
            NSLog(@"Final result: %@", value);
        }];
}

- (void)demonstrateErrorHandling {
    NSLog(@"\n=== Error Handling ===\n");

    // Catch and recover
    NSError *error = [NSError errorWithDomain:@"example" code:500 userInfo:nil];
    PKFuture *failing = [PKFuture rejectedWithError:error];

    PKFuture *recovered = [failing catch:^id _Nullable(NSError *err) {
        NSLog(@"Caught error: %@, recovering...", err);
        return @"Recovered value";
    }];

    [recovered onSuccess:^(id _Nullable value) {
        NSLog(@"Successfully recovered: %@", value);
    }];

    // Finally block
    PKFuture *withFinally = [[PKFuture fulfilledWithValue:@"data"]
        finally:^{
            NSLog(@"Finally block executed (cleanup)");
        }];
}

- (void)demonstrateComposition {
    NSLog(@"\n=== Future Composition ===\n");

    // all: wait for all futures
    PKFuture *f1 = [PKFuture after:0.3 value:@"First"];
    PKFuture *f2 = [PKFuture after:0.2 value:@"Second"];
    PKFuture *f3 = [PKFuture after:0.1 value:@"Third"];

    PKFuture *all = [PKFuture all:@[f1, f2, f3]];
    [all onSuccess:^(NSArray *results) {
        NSLog(@"All completed: %@", results);
    }];

    // race: first to complete
    PKFuture *r1 = [PKFuture after:0.5 value:@"Slow"];
    PKFuture *r2 = [PKFuture after:0.1 value:@"Fast"];

    PKFuture *race = [PKFuture race:@[r1, r2]];
    [race onSuccess:^(id _Nullable value) {
        NSLog(@"Race winner: %@", value);
    }];

    // any: first successful
    PKFuture *a1 = [PKFuture rejectedWithError:[NSError errorWithDomain:@"e" code:1 userInfo:nil]];
    PKFuture *a2 = [PKFuture after:0.2 value:@"Success"];

    PKFuture *any = [PKFuture any:@[a1, a2]];
    [any onSuccess:^(id _Nullable value) {
        NSLog(@"Any succeeded: %@", value);
    }];
}

- (void)demonstrateWhileLoop {
    NSLog(@"\n=== While Loops ===\n");

    // while loop with condition
    __block NSInteger counter = 0;

    PKFuture *whileLoop = [PKFuture while:^BOOL(id _Nullable value) {
        return counter < 5;
    } do:^PKFuture * _Nonnull(id _Nullable value) {
        NSInteger current = counter++;
        NSLog(@"While iteration %ld", (long)current);
        return [PKFuture after:0.1 value:@(current)];
    } initial:@0];

    [whileLoop onSuccess:^(id _Nullable value) {
        NSLog(@"While loop completed with value: %@", value);
    }];
}

- (void)demonstrateRepeat {
    NSLog(@"\n=== Repeat Operations ===\n");

    // Repeat operation N times
    PKFuture *repeated = [PKFuture repeat:3 do:^PKFuture * _Nonnull(NSUInteger iteration) {
        NSLog(@"Repeat iteration %lu", (unsigned long)iteration);
        return [PKFuture after:0.1 value:@(iteration)];
    }];

    [repeated onSuccess:^(id _Nullable value) {
        NSLog(@"Repeat completed: %@", value);
    }];
}

- (void)demonstrateForEach {
    NSLog(@"\n=== ForEach ===\n");

    NSArray *items = @[@"Apple", @"Banana", @"Cherry"];

    PKFuture *forEach = [PKFuture forEach:items do:^PKFuture * _Nonnull(id item, NSUInteger index) {
        NSLog(@"Processing item %lu: %@", (unsigned long)index, item);
        return [PKFuture after:0.1 value:[item uppercaseString]];
    }];

    [forEach onSuccess:^(NSArray *results) {
        NSLog(@"ForEach results: %@", results);
    }];
}

- (void)demonstrateTiming {
    NSLog(@"\n=== Timing Operations ===\n");

    // Timeout
    PKFuture *slow = [PKFuture after:2.0 value:@"Too slow"];
    PKFuture *withTimeout = [slow timeout:0.5];

    [withTimeout onFailure:^(NSError *error) {
        NSLog(@"Timed out as expected: %@", error.localizedDescription);
    }];

    // Delay
    PKFuture *delayed = [[PKFuture fulfilledWithValue:@"Delayed"]
        delay:0.3];

    [delayed onSuccess:^(id _Nullable value) {
        NSLog(@"Delayed value: %@", value);
    }];
}

- (void)demonstrateFiltering {
    NSLog(@"\n=== Filtering ===\n");

    PKFuture *value = [PKFuture fulfilledWithValue:@42];

    // Filter with predicate
    PKFuture *filtered = [value filter:^BOOL(id _Nullable val) {
        return [val integerValue] > 50;
    }];

    [filtered onFailure:^(NSError *error) {
        NSLog(@"Filtered out (value too small): %@", error.localizedDescription);
    }];

    // Successful filter
    PKFuture *passed = [value filter:^BOOL(id _Nullable val) {
        return [val integerValue] > 30;
    }];

    [passed onSuccess:^(id _Nullable val) {
        NSLog(@"Filter passed: %@", val);
    }];
}

- (void)demonstratePluginIntegration {
    NSLog(@"\n=== Plugin Integration with Futures ===\n");

    PKPlugInManager *manager = [PKPlugInManager sharedManager];

    // Discover plugins
    [manager discoverPlugInsWithCompletion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *error) {
        if (plugIns.count == 0) {
            NSLog(@"No plugins found for demonstration");
            return;
        }

        PKPlugInInfo *info = plugIns.firstObject;

        // Connect using futures
        PKFuture *connectFuture = [PKFuture fromAsync:^(void (^completion)(id _Nullable, NSError * _Nullable)) {
            [manager connectToPlugIn:info.identifier
                       configuration:@{}
                          completion:^(PKConnection *connection, NSError *err) {
                completion(connection, err);
            }];
        }];

        // Chain operations
        PKFuture *pipeline = [[[connectFuture
            thenFuture:^PKFuture * _Nullable(PKConnection *connection) {
                NSLog(@"Connected, getting capabilities...");
                return [connection getCapabilities];
            }]
            then:^id _Nullable(NSDictionary *capabilities) {
                NSLog(@"Capabilities: %@", capabilities);
                return capabilities;
            }]
            catch:^id _Nullable(NSError *err) {
                NSLog(@"Error in pipeline: %@", err);
                return @{@"error": err.localizedDescription};
            }];

        [pipeline onComplete:^(id _Nullable value, NSError *err) {
            NSLog(@"Pipeline completed: %@", value ?: err);
        }];
    }];
}

- (void)demonstrateAdvancedPatterns {
    NSLog(@"\n=== Advanced Patterns ===\n");

    // Retry with exponential backoff
    __block NSInteger attempts = 0;
    PKFuture *unreliable = [PKFuture futureWithResolver:^(void (^fulfill)(id _Nullable), void (^reject)(NSError *)) {
        attempts++;
        NSLog(@"Attempt %ld", (long)attempts);

        if (attempts < 3) {
            NSError *err = [NSError errorWithDomain:@"retry" code:1 userInfo:nil];
            reject(err);
        } else {
            fulfill(@"Success on attempt 3");
        }
    }];

    // Sequential execution
    NSArray<PKFuture * (^)(void)> *operations = @[
        ^PKFuture * { return [PKFuture after:0.1 value:@"Step 1"]; },
        ^PKFuture * { return [PKFuture after:0.1 value:@"Step 2"]; },
        ^PKFuture * { return [PKFuture after:0.1 value:@"Step 3"]; }
    ];

    PKFuture *sequence = [PKFuture sequence:operations];
    [sequence onSuccess:^(NSArray *results) {
        NSLog(@"Sequence completed: %@", results);
    }];

    // Zip two futures
    PKFuture *name = [PKFuture fulfilledWithValue:@"John"];
    PKFuture *age = [PKFuture fulfilledWithValue:@30];

    PKFuture *zipped = [name zip:age];
    [zipped onSuccess:^(NSArray *values) {
        NSLog(@"Zipped: name=%@, age=%@", values[0], values[1]);
    }];
}

- (void)runAllExamples {
    NSLog(@"\n╔════════════════════════════════════════╗");
    NSLog(@"║  PlugInKit Futures Examples           ║");
    NSLog(@"╚════════════════════════════════════════╝\n");

    [self demonstrateBasicFutures];
    [self demonstrateChaining];
    [self demonstrateErrorHandling];
    [self demonstrateComposition];
    [self demonstrateWhileLoop];
    [self demonstrateRepeat];
    [self demonstrateForEach];
    [self demonstrateTiming];
    [self demonstrateFiltering];
    [self demonstrateAdvancedPatterns];
    [self demonstratePluginIntegration];

    // Wait for async operations
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                  dispatch_get_main_queue(), ^{
        NSLog(@"\n=== All Examples Complete ===\n");
        exit(0);
    });
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        FuturesExample *example = [[FuturesExample alloc] init];
        [example runAllExamples];

        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
