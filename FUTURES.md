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
- [Plugin Integration](#plugin-integration)
- [Swift Support](#swift-support)
- [Advanced Patterns](#advanced-patterns)

## Overview

PKFuture provides a powerful, composable abstraction for asynchronous operations over XPC. Inspired by JavaScript Promises and Scala Futures, it supports:

- **then/catch/finally** - Chaining and error handling
- **all/any/race** - Composition of multiple futures
- **while/repeat/forEach** - Iteration patterns
- **timeout/delay** - Timing control
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
