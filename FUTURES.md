# PlugInKit Futures Guide

Complete guide to using futures/promises in PlugInKit for asynchronous XPC communication.

## Table of Contents

- [Overview](#overview)
- [Basic Usage](#basic-usage)
- [Chaining Operations](#chaining-operations)
- [Error Handling](#error-handling)
- [Composition](#composition)
- [Iteration](#iteration)
- [Timing](#timing)
- [Cancellation](#cancellation)
- [Progress Reporting](#progress-reporting)
- [Plugin Integration](#plugin-integration)
- [Swift Support](#swift-support)
- [Advanced Patterns](#advanced-patterns)

## Overview

PKFuture provides a powerful, composable abstraction for asynchronous operations over XPC. Inspired by JavaScript Promises and Scala Futures, it supports:

- **then/catch/finally** - Chaining and error handling
- **all/any/race** - Composition of multiple futures
- **while/repeat/forEach** - Iteration patterns
- **timeout/delay** - Timing control
- **Cancellation** - Cancel in-flight operations with tokens
- **Progress reporting** - Track operation progress with NSProgress
- **Full XPC support** - NSSecureCoding for seamless plugin communication
- **Swift integration** - async/await, Combine, and type-safe wrappers

## Basic Usage

### Creating Futures

```objc
// With resolver
PKFuture *future = [PKFuture futureWithResolver:^(void (^fulfill)(id), void (^reject)(NSError *)) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Async operation
        fulfill(@"result");
    });
}];

// Already fulfilled
PKFuture *immediate = [PKFuture fulfilledWithValue:@"value"];

// Already rejected
NSError *error = [NSError errorWithDomain:@"example" code:1 userInfo:nil];
PKFuture *failed = [PKFuture rejectedWithError:error];

// From async operation
PKFuture *async = [PKFuture fromAsync:^(void (^completion)(id, NSError *)) {
    [someObject performAsyncOperation:^(id result, NSError *error) {
        completion(result, error);
    }];
}];
```

### Observing Results

```objc
// Success only
[future onSuccess:^(id value) {
    NSLog(@"Success: %@", value);
}];

// Failure only
[future onFailure:^(NSError *error) {
    NSLog(@"Error: %@", error);
}];

// Both
[future onComplete:^(id value, NSError *error) {
    if (error) {
        NSLog(@"Failed: %@", error);
    } else {
        NSLog(@"Succeeded: %@", value);
    }
}];
```

## Chaining Operations

### then

Transform successful values:

```objc
PKFuture *result = [[[future
    then:^id(id value) {
        return @([value integerValue] * 2);
    }]
    then:^id(id value) {
        return [NSString stringWithFormat:@"Result: %@", value];
    }]
    onSuccess:^(id value) {
        NSLog(@"%@", value); // "Result: 20"
    }];
```

### thenFuture (flatMap)

Chain async operations:

```objc
PKFuture *chain = [future thenFuture:^PKFuture *(id value) {
    // Return another future
    return [self fetchDataForId:value];
}];
```

### map

Transform values (alias for then):

```objc
PKFuture *mapped = [future map:^id(id value) {
    return [value uppercaseString];
}];
```

## Error Handling

### catch

Recover from errors:

```objc
PKFuture *recovered = [future catch:^id(NSError *error) {
    NSLog(@"Recovering from: %@", error);
    return @"default value";
}];
```

### catchFuture

Async error recovery:

```objc
PKFuture *recovered = [future catchFuture:^PKFuture *(NSError *error) {
    return [self fetchFallbackData];
}];
```

### finally

Execute cleanup regardless of outcome:

```objc
PKFuture *withCleanup = [future finally:^{
    NSLog(@"Cleanup executed");
    [self closeConnection];
}];
```

## Composition

### all

Wait for all futures to complete:

```objc
NSArray *futures = @[future1, future2, future3];
PKFuture *all = [PKFuture all:futures];

[all onSuccess:^(NSArray *results) {
    NSLog(@"All completed: %@", results);
}];
```

### any

First successful future:

```objc
PKFuture *any = [PKFuture any:futures];

[any onSuccess:^(id value) {
    NSLog(@"First success: %@", value);
}];
```

### race

First completed future (success or failure):

```objc
PKFuture *race = [PKFuture race:futures];

[race onComplete:^(id value, NSError *error) {
    NSLog(@"Winner: %@ / %@", value, error);
}];
```

### sequence

Execute futures sequentially:

```objc
NSArray<PKFuture * (^)(void)> *operations = @[
    ^PKFuture * { return [self step1]; },
    ^PKFuture * { return [self step2]; },
    ^PKFuture * { return [self step3]; }
];

PKFuture *sequence = [PKFuture sequence:operations];
```

### zip

Combine two futures:

```objc
PKFuture *zipped = [future1 zip:future2];

[zipped onSuccess:^(NSArray *values) {
    id value1 = values[0];
    id value2 = values[1];
}];
```

## Iteration

### while

Loop while condition is true:

```objc
__block NSInteger counter = 0;

PKFuture *loop = [PKFuture while:^BOOL(id value) {
    return counter < 10;
} do:^PKFuture *(id value) {
    return [self processItem:counter++];
} initial:nil];
```

### whileTrue

Simple condition without value:

```objc
__block BOOL hasMore = YES;

PKFuture *loop = [PKFuture whileTrue:^BOOL {
    return hasMore;
} do:^PKFuture * {
    return [self fetchNextBatch]
        .then(^id(NSArray *items) {
            hasMore = items.count > 0;
            return items;
        });
}];
```

### repeat

Repeat N times:

```objc
PKFuture *repeated = [PKFuture repeat:5 do:^PKFuture *(NSUInteger iteration) {
    NSLog(@"Iteration %lu", (unsigned long)iteration);
    return [self performOperation:iteration];
}];
```

### forEach

Process array items sequentially:

```objc
NSArray *items = @[@"a", @"b", @"c"];

PKFuture *forEach = [PKFuture forEach:items do:^PKFuture *(id item, NSUInteger index) {
    return [self processItem:item];
}];

[forEach onSuccess:^(NSArray *results) {
    NSLog(@"All items processed: %@", results);
}];
```

## Timing

### timeout

Add timeout to future:

```objc
PKFuture *withTimeout = [future timeout:5.0];

[withTimeout onFailure:^(NSError *error) {
    if (error.code == PKFutureErrorTimeout) {
        NSLog(@"Operation timed out");
    }
}];
```

### delay

Delay resolution:

```objc
PKFuture *delayed = [future delay:2.0];
```

### after

Create future that resolves after delay:

```objc
PKFuture *delayed = [PKFuture after:3.0 value:@"delayed value"];
```

## Cancellation

### PKCancellationToken

Cancel asynchronous operations gracefully:

```objc
PKCancellationToken *token = [[PKCancellationToken alloc] init];

// Register cancellation callback
[token onCancelled:^{
    NSLog(@"Operation cancelled");
    [self cleanup];
}];

// Cancel the operation
[token cancel];

// Check if cancelled
if (token.isCancelled) {
    // Handle cancellation
}
```

### Cancelling Futures

Attach a cancellation token to a future:

```objc
PKCancellationToken *token = [[PKCancellationToken alloc] init];

PKFuture *future = [[connection sendMessage:@{@"action": @"process"}]
    attachCancellationToken:token];

[future onSuccess:^(id result) {
    NSLog(@"Completed: %@", result);
}];

[future onCancelled:^{
    NSLog(@"Future was cancelled");
}];

// Cancel the operation
[token cancel]; // Triggers onCancelled and rejects future with PKErrorOperationCancelled
```

### Direct Future Cancellation

Cancel a future directly without a token:

```objc
PKFuture *future = [connection sendMessage:message];

[future onCancelled:^{
    NSLog(@"Cancelled");
}];

// Later...
[future cancel]; // Rejects with cancellation error
```

### Creating Cancellable Futures

Create a future that respects cancellation:

```objc
PKCancellationToken *token = [[PKCancellationToken alloc] init];

PKFuture *future = [PKFuture futureWithResolver:^(void (^fulfill)(id),
                                                   void (^reject)(NSError *),
                                                   PKCancellationToken *token) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 100; i++) {
            // Check cancellation periodically
            if (token.isCancelled) {
                NSError *error = [NSError pk_errorWithCode:PKErrorOperationCancelled
                                               description:@"Operation cancelled"];
                reject(error);
                return;
            }

            // Do work
            [self processItem:i];
        }

        fulfill(@"completed");
    });
} cancellationToken:token];

// Can cancel anytime
[token cancel];
```

### Linked Cancellation Tokens

Create a token that cancels when any parent cancels:

```objc
PKCancellationToken *token1 = [[PKCancellationToken alloc] init];
PKCancellationToken *token2 = [[PKCancellationToken alloc] init];

// Linked token cancels if either parent cancels
PKCancellationToken *linkedToken = [PKCancellationToken linkedTokenWithTokens:@[token1, token2]];

[linkedToken onCancelled:^{
    NSLog(@"One of the parent tokens was cancelled");
}];

[token1 cancel]; // Triggers linkedToken cancellation
```

### Cancellation with Plugin Operations

Cancel long-running plugin operations:

```objc
PKConnection *connection = [self connectionForPlugIn:identifier];
PKCancellationToken *token = [[PKCancellationToken alloc] init];

PKFuture *future = [[connection sendMessage:@{
    @"action": @"processLargeFile",
    @"path": @"/path/to/file"
}] attachCancellationToken:token];

// Show cancel button
self.cancelButton.enabled = YES;
self.cancelButton.target = self;
self.cancelButton.action = @selector(cancelOperation:);
self.currentToken = token;

// Later, when user clicks cancel
- (void)cancelOperation:(id)sender {
    [self.currentToken cancel];
    self.cancelButton.enabled = NO;
}
```

## Progress Reporting

### Basic Progress Tracking

Track operation progress with NSProgress:

```objc
PKFuture *future = [PKFuture futureWithTotalUnitCount:100
                                             resolver:^(void (^fulfill)(id),
                                                        void (^reject)(NSError *),
                                                        NSProgress *progress) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i <= 100; i++) {
            // Update progress
            progress.completedUnitCount = i;

            // Do work
            [NSThread sleepForTimeInterval:0.1];
        }

        fulfill(@"done");
    });
}];

// Observe progress
[future reportProgress:^(NSProgress *progress) {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressBar.progress = progress.fractionCompleted;
        self.statusLabel.text = [NSString stringWithFormat:@"%.0f%%",
                                progress.fractionCompleted * 100];
    });
}];
```

### Progress with Custom Units

Use meaningful unit counts:

```objc
NSArray *files = @[@"file1.txt", @"file2.txt", @"file3.txt"];

PKFuture *future = [PKFuture futureWithTotalUnitCount:files.count
                                             resolver:^(void (^fulfill)(id),
                                                        void (^reject)(NSError *),
                                                        NSProgress *progress) {
    progress.localizedDescription = @"Processing files";

    for (NSInteger i = 0; i < files.count; i++) {
        [self processFile:files[i]];
        progress.completedUnitCount = i + 1;
        progress.localizedAdditionalDescription = [NSString stringWithFormat:@"%@ of %@",
                                                   @(i + 1), @(files.count)];
    }

    fulfill(@"all files processed");
}];
```

### Attaching Progress to Existing Futures

Add progress to any future:

```objc
PKFuture *future = [connection sendMessage:message];
NSProgress *progress = [NSProgress progressWithTotalUnitCount:100];

[[future withProgress:progress]
    reportProgress:^(NSProgress *p) {
        NSLog(@"Progress: %.0f%%", p.fractionCompleted * 100);
    }];

// Update progress elsewhere
progress.completedUnitCount = 50;
```

### Progress with Cancellation

Combine progress and cancellation:

```objc
PKCancellationToken *token = [[PKCancellationToken alloc] init];

PKFuture *future = [PKFuture futureWithTotalUnitCount:1000
                                             resolver:^(void (^fulfill)(id),
                                                        void (^reject)(NSError *),
                                                        NSProgress *progress) {
    for (int i = 0; i < 1000; i++) {
        // Check cancellation
        if (token.isCancelled) {
            NSError *error = [NSError pk_errorWithCode:PKErrorOperationCancelled
                                           description:@"User cancelled"];
            reject(error);
            return;
        }

        // Update progress
        progress.completedUnitCount = i;

        // Do work
        [self processItem:i];
    }

    fulfill(@"completed");
}];

[[future attachCancellationToken:token]
    reportProgress:^(NSProgress *progress) {
        self.progressBar.progress = progress.fractionCompleted;
    }];

// User can cancel
[token cancel];
```

### Hierarchical Progress

Create parent-child progress relationships:

```objc
NSProgress *parentProgress = [NSProgress progressWithTotalUnitCount:3];

// Child task 1
[parentProgress becomeCurrentWithPendingUnitCount:1];
PKFuture *task1 = [PKFuture futureWithProgress:^(void (^fulfill)(id),
                                                  void (^reject)(NSError *),
                                                  NSProgress *progress) {
    progress.totalUnitCount = 100;
    // Do work...
    fulfill(@"task1 done");
}];
[parentProgress resignCurrent];

// Child task 2
[parentProgress becomeCurrentWithPendingUnitCount:1];
PKFuture *task2 = [PKFuture futureWithProgress:^(void (^fulfill)(id),
                                                  void (^reject)(NSError *),
                                                  NSProgress *progress) {
    progress.totalUnitCount = 200;
    // Do work...
    fulfill(@"task2 done");
}];
[parentProgress resignCurrent];

// Child task 3
[parentProgress becomeCurrentWithPendingUnitCount:1];
PKFuture *task3 = [PKFuture futureWithProgress:^(void (^fulfill)(id),
                                                  void (^reject)(NSError *),
                                                  NSProgress *progress) {
    progress.totalUnitCount = 50;
    // Do work...
    fulfill(@"task3 done");
}];
[parentProgress resignCurrent];

// Observe overall progress
[parentProgress addObserver:self
                 forKeyPath:@"fractionCompleted"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];
```

### Progress with Plugin Operations

Report progress from plugin operations:

```objc
PKConnection *connection = [self connectionForPlugIn:identifier];

// Send message requesting progress updates
id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *error) {
    NSLog(@"Error: %@", error);
}];

NSProgress *progress = [NSProgress progressWithTotalUnitCount:100];

[plugin handleMessage:@{
    @"action": @"processWithProgress",
    @"data": someData
} reply:^(NSDictionary *response, NSError *error) {
    if (error) {
        NSLog(@"Error: %@", error);
    } else {
        NSLog(@"Complete: %@", response);
    }
}];

// Plugin can send progress updates via notifications
// or separate progress channel
```

### KVO Progress Observation

Use KVO for fine-grained progress monitoring:

```objc
PKFuture *future = [PKFuture futureWithTotalUnitCount:100
                                             resolver:^(void (^fulfill)(id),
                                                        void (^reject)(NSError *),
                                                        NSProgress *progress) {
    // Long operation...
}];

NSProgress *progress = future.progress;

[progress addObserver:self
           forKeyPath:@"fractionCompleted"
              options:NSKeyValueObservingOptionNew
              context:NULL];

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"fractionCompleted"]) {
        NSProgress *progress = (NSProgress *)object;
        NSLog(@"Progress: %.2f%%", progress.fractionCompleted * 100);
    }
}
```

## Plugin Integration

### Connection Operations

```objc
PKConnection *connection = /* ... */;

// Initialize plugin
PKFuture *init = [connection initializePluginWithConfiguration:@{
    @"mode": @"production"
}];

// Get capabilities
PKFuture *caps = [connection getCapabilities];

// Send message
PKFuture *response = [connection sendMessage:@{
    @"action": @"process",
    @"data": @"input"
}];

// Chain operations
[[[[connection getCapabilities]
    then:^id(NSDictionary *caps) {
        NSLog(@"Capabilities: %@", caps);
        return @{@"action": @"echo"};
    }]
    thenFuture:^PKFuture *(NSDictionary *message) {
        return [connection sendMessage:message];
    }]
    onSuccess:^(NSDictionary *result) {
        NSLog(@"Result: %@", result);
    }];
```

### Retry Pattern

```objc
PKFuture *withRetry = [connection retry:^PKFuture * {
    return [connection pollFuture];
} maxAttempts:3];
```

### Execute with Timeout

```objc
PKFuture *result = [connection execute:^PKFuture * {
    return [connection sendMessage:message];
} timeout:10.0];
```

## Swift Support

### Basic Usage

```swift
// Create future
let future = PKFuture { fulfill, reject in
    DispatchQueue.global().async {
        fulfill("result")
    }
}

// Type-safe wrapper
let typed = Future<String> { fulfill, reject in
    fulfill("type-safe result")
}

// Promise style
let promise = PKFuture.promise<Int> { resolve in
    resolve(.success(42))
}
```

### Chaining

```swift
future
    .then { value in
        print("Step 1: \(value)")
        return processedValue
    }
    .then { value in
        print("Step 2: \(value)")
        return finalValue
    }
    .onSuccess { value in
        print("Done: \(value)")
    }

// Type-safe
Future.resolved(10)
    .map { $0 * 2 }
    .map { "Result: \($0)" }
    .onSuccess { print($0) }
```

### Operators

```swift
// Pipe
let result = future |> { $0.uppercased() } |> { "Prefix: \($0)" }

// Bind (flatMap)
let bound = future >>- { value in
    PKFuture.fulfilled(withValue: processedValue)
}
```

### Async/Await

```swift
@available(macOS 12.0, *)
func example() async throws {
    // Create from async
    let future = PKFuture.from {
        try await someAsyncOperation()
    }

    // Convert to async
    let result: String = try await future.async()

    // Type-safe async
    let typed = Future<Int> { fulfill, _ in
        Task { fulfill(42) }
    }
    let value = try await typed.async()

    // Concurrent execution
    let results = try await PKFuture.concurrent([
        { try await task1() },
        { try await task2() },
        { try await task3() }
    ])

    // Retry with async
    let retried = try await PKFuture.retry(maxAttempts: 3) {
        try await unreliableOperation()
    }

    // Timeout with async
    let timedResult = try await PKFuture.withTimeout(5.0) {
        try await longOperation()
    }
}
```

### Combine Integration

```swift
import Combine

// Future to Publisher
let publisher = future.publisher

publisher
    .sink(
        receiveCompletion: { completion in print(completion) },
        receiveValue: { value in print(value) }
    )
    .store(in: &cancellables)

// Publisher to Future
let fromPublisher = PKFuture.from(somePublisher)
```

### Result Builder

```swift
let pipeline = PKFuture.execute {
    PKFuture.after(0.1, value: "Step 1")
    PKFuture.after(0.1, value: "Step 2")
    PKFuture.after(0.1, value: "Step 3")
}

pipeline.onSuccess { results in
    print("Pipeline complete: \(results)")
}
```

## Advanced Patterns

### Retry with Exponential Backoff

```objc
__block NSInteger attempt = 0;
__block NSTimeInterval delay = 1.0;

void (^retryOperation)(void) = ^void(void) {};
__block void (^retryBlock)(void) = ^{
    attempt++;

    PKFuture *future = [self unreliableOperation];

    [future onComplete:^(id value, NSError *error) {
        if (error && attempt < 5) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                          dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                delay *= 2; // Exponential backoff
                retryBlock();
            });
        } else if (error) {
            NSLog(@"Failed after %ld attempts", (long)attempt);
        } else {
            NSLog(@"Succeeded on attempt %ld", (long)attempt);
        }
    }];
};

retryOperation = retryBlock;
retryBlock();
```

### Circuit Breaker

```objc
@interface CircuitBreaker : NSObject
@property (nonatomic, assign) NSUInteger failureCount;
@property (nonatomic, assign) NSUInteger threshold;
@property (nonatomic, assign) BOOL isOpen;
@end

@implementation CircuitBreaker

- (PKFuture *)execute:(PKFuture * (^)(void))operation {
    if (self.isOpen) {
        NSError *error = [NSError errorWithDomain:@"circuit"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Circuit open"}];
        return [PKFuture rejectedWithError:error];
    }

    PKFuture *result = operation();

    [result onComplete:^(id value, NSError *error) {
        if (error) {
            self.failureCount++;
            if (self.failureCount >= self.threshold) {
                self.isOpen = YES;
                // Reset after timeout
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)),
                              dispatch_get_main_queue(), ^{
                    self.isOpen = NO;
                    self.failureCount = 0;
                });
            }
        } else {
            self.failureCount = 0;
        }
    }];

    return result;
}

@end
```

### Batching

```objc
- (PKFuture *)batchProcess:(NSArray *)items batchSize:(NSUInteger)batchSize {
    NSMutableArray<PKFuture * (^)(void)> *batches = [NSMutableArray array];

    for (NSUInteger i = 0; i < items.count; i += batchSize) {
        NSUInteger end = MIN(i + batchSize, items.count);
        NSArray *batch = [items subarrayWithRange:NSMakeRange(i, end - i)];

        [batches addObject:^PKFuture * {
            NSArray<PKFuture *> *futures = [batch.map(^(id item) {
                return [self processItem:item];
            })];
            return [PKFuture all:futures];
        }];
    }

    return [PKFuture sequence:batches];
}
```

### Caching

```objc
@interface FutureCache : NSObject
@property (nonatomic, strong) NSCache *cache;
@end

@implementation FutureCache

- (PKFuture *)memoize:(NSString *)key operation:(PKFuture * (^)(void))operation {
    PKFuture *cached = [self.cache objectForKey:key];
    if (cached) {
        return cached;
    }

    PKFuture *future = operation();
    [self.cache setObject:future forKey:key];

    [future onComplete:^(id value, NSError *error) {
        if (error) {
            // Remove from cache on error
            [self.cache removeObjectForKey:key];
        }
    }];

    return future;
}

@end
```

## Best Practices

1. **Always handle errors** - Use `catch` or `onFailure` to handle rejections
2. **Avoid blocking** - Don't use `wait` on the main thread
3. **Chain instead of nest** - Use `then`/`thenFuture` instead of nested callbacks
4. **Use timeouts** - Add timeouts to prevent hanging operations
5. **Clean up resources** - Use `finally` for cleanup
6. **Type safety in Swift** - Use `Future<T>` wrapper for type safety
7. **Retry wisely** - Use exponential backoff for retries
8. **Composition over complexity** - Use `all`/`sequence` instead of manual orchestration
9. **Make operations cancellable** - Provide cancellation tokens for long-running operations
10. **Check cancellation periodically** - In loops and long operations, check `token.isCancelled`
11. **Report meaningful progress** - Use appropriate total unit counts and localized descriptions
12. **Combine cancellation and progress** - Long operations should support both
13. **Clean up on cancellation** - Use `onCancelled` to release resources
14. **Don't forget progress completion** - Ensure `completedUnitCount` reaches `totalUnitCount`

## Performance Tips

- Futures are thread-safe but use serial queues internally
- Callbacks execute on background queues by default
- Use `synchronousRemotePlugInWithErrorHandler` sparingly
- Batch operations when possible
- Cache futures for expensive operations
- Clean up completed futures to avoid memory leaks

## XPC Considerations

- Futures are NSSecureCoding-compliant for XPC transfer
- State (pending/fulfilled/rejected) is preserved across XPC
- Callbacks are not transferred - only values and errors
- Use protocol extensions for future-based XPC methods
- Large value transfers should be chunked

## Examples

See complete examples in:
- `Examples/FuturesExample/FuturesExample.m` - Objective-C examples
- `Examples/SwiftFuturesExample/SwiftFuturesExample.swift` - Swift examples
