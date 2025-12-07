//
//  PKFuture.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PKFuture<__covariant ValueType>;

/// State of a future
typedef NS_ENUM(NSInteger, PKFutureState) {
    PKFutureStatePending,
    PKFutureStateFulfilled,
    PKFutureStateRejected
};

/// Type for future transformation blocks
typedef id _Nullable (^PKFutureTransform)(id _Nullable value);

/// Type for future error recovery blocks
typedef id _Nullable (^PKFutureRecover)(NSError *error);

/// Type for future condition blocks
typedef BOOL (^PKFutureCondition)(id _Nullable value);

/// Type for future action blocks
typedef void (^PKFutureAction)(id _Nullable value);

/// Type for future error action blocks
typedef void (^PKFutureErrorAction)(NSError *error);

/// A future represents an eventual value that may be available now, later, or never.
/// Futures are immutable and thread-safe, supporting composition via then, catch, and other combinators.
@interface PKFuture<__covariant ValueType> : NSObject <NSSecureCoding>

/// Current state of the future
@property (nonatomic, assign, readonly) PKFutureState state;

/// The fulfilled value (if state is fulfilled)
@property (nonatomic, strong, readonly, nullable) ValueType value;

/// The rejection error (if state is rejected)
@property (nonatomic, strong, readonly, nullable) NSError *error;

/// Whether the future has completed (fulfilled or rejected)
@property (nonatomic, assign, readonly) BOOL isCompleted;

/// Create a pending future with a resolver block
/// @param resolver Block that receives fulfill and reject functions
+ (instancetype)futureWithResolver:(void (^)(void (^fulfill)(ValueType _Nullable value),
                                             void (^reject)(NSError *error)))resolver;

/// Create an immediately fulfilled future
/// @param value The fulfilled value
+ (instancetype)fulfilledWithValue:(nullable ValueType)value;

/// Create an immediately rejected future
/// @param error The rejection error
+ (instancetype)rejectedWithError:(NSError *)error;

// MARK: - Transformation

/// Transform the future's value if fulfilled
/// @param transform Transformation block
/// @return New future with transformed value
- (PKFuture *)then:(PKFutureTransform)transform;

/// Transform the future's value asynchronously
/// @param transform Transformation block that returns a future
/// @return New future with transformed value
- (PKFuture *)thenFuture:(PKFuture * _Nullable (^)(id _Nullable value))transform;

/// Map the future's value
/// @param mapper Mapping function
/// @return New future with mapped value
- (PKFuture *)map:(id _Nullable (^)(ValueType _Nullable value))mapper;

/// Flat map the future's value
/// @param mapper Mapping function that returns a future
/// @return New future with flat-mapped value
- (PKFuture *)flatMap:(PKFuture * _Nullable (^)(ValueType _Nullable value))mapper;

// MARK: - Error Handling

/// Recover from an error
/// @param recover Recovery block
/// @return New future with recovered value
- (PKFuture *)catch:(PKFutureRecover)recover;

/// Recover from an error asynchronously
/// @param recover Recovery block that returns a future
/// @return New future with recovered value
- (PKFuture *)catchFuture:(PKFuture * _Nullable (^)(NSError *error))recover;

/// Execute a block regardless of success or failure
/// @param finalizer Block to execute
/// @return New future with same result
- (PKFuture *)finally:(void (^)(void))finalizer;

// MARK: - Side Effects

/// Execute a block if the future is fulfilled
/// @param action Action to execute
/// @return Same future for chaining
- (PKFuture *)onSuccess:(void (^)(ValueType _Nullable value))action;

/// Execute a block if the future is rejected
/// @param action Action to execute
/// @return Same future for chaining
- (PKFuture *)onFailure:(void (^)(NSError *error))action;

/// Execute a block when the future completes
/// @param action Action to execute
/// @return Same future for chaining
- (PKFuture *)onComplete:(void (^)(ValueType _Nullable value, NSError * _Nullable error))action;

// MARK: - Filtering

/// Filter the future's value
/// @param predicate Predicate to test
/// @return New future that rejects if predicate fails
- (PKFuture *)filter:(BOOL (^)(ValueType _Nullable value))predicate;

/// Filter the future's value with custom error
/// @param predicate Predicate to test
/// @param error Error to use if predicate fails
/// @return New future that rejects if predicate fails
- (PKFuture *)filter:(BOOL (^)(ValueType _Nullable value))predicate
               error:(NSError *)error;

// MARK: - Timing

/// Add a timeout to the future
/// @param timeout Timeout in seconds
/// @return New future that rejects if timeout expires
- (PKFuture *)timeout:(NSTimeInterval)timeout;

/// Add a timeout with custom error
/// @param timeout Timeout in seconds
/// @param error Error to use on timeout
/// @return New future that rejects if timeout expires
- (PKFuture *)timeout:(NSTimeInterval)timeout error:(NSError *)error;

/// Delay the future's resolution
/// @param delay Delay in seconds
/// @return New future delayed by the specified time
- (PKFuture *)delay:(NSTimeInterval)delay;

// MARK: - Composition

/// Wait for all futures to complete
/// @param futures Array of futures
/// @return Future that fulfills with array of values when all complete
+ (PKFuture<NSArray *> *)all:(NSArray<PKFuture *> *)futures;

/// Wait for any future to complete
/// @param futures Array of futures
/// @return Future that fulfills with first completed value
+ (PKFuture *)any:(NSArray<PKFuture *> *)futures;

/// Race multiple futures
/// @param futures Array of futures
/// @return Future that completes with first future's result
+ (PKFuture *)race:(NSArray<PKFuture *> *)futures;

/// Execute futures sequentially
/// @param futures Array of future creators
/// @return Future that fulfills when all complete sequentially
+ (PKFuture<NSArray *> *)sequence:(NSArray<PKFuture * (^)(void)> *)futures;

// MARK: - Iteration

/// Repeat a future-returning operation while condition is true
/// @param condition Condition to check before each iteration
/// @param operation Operation that returns a future
/// @return Future that fulfills when condition becomes false
+ (PKFuture *)whileTrue:(BOOL (^)(void))condition
                     do:(PKFuture * (^)(void))operation;

/// Repeat a future-returning operation with value while condition is true
/// @param condition Condition to check with accumulated value
/// @param operation Operation that returns a future
/// @param initial Initial value
/// @return Future that fulfills with final accumulated value
+ (PKFuture *)while:(BOOL (^)(id _Nullable value))condition
                 do:(PKFuture * (^)(id _Nullable value))operation
            initial:(nullable id)initial;

/// Repeat operation a specific number of times
/// @param count Number of times to repeat
/// @param operation Operation that returns a future
/// @return Future that fulfills when all iterations complete
+ (PKFuture *)repeat:(NSUInteger)count
                  do:(PKFuture * (^)(NSUInteger iteration))operation;

/// Execute operation for each item in array
/// @param items Array of items
/// @param operation Operation to execute for each item
/// @return Future that fulfills with array of results
+ (PKFuture<NSArray *> *)forEach:(NSArray *)items
                              do:(PKFuture * (^)(id item, NSUInteger index))operation;

// MARK: - Synchronization

/// Wait for the future to complete (blocks current thread)
/// @param timeout Maximum time to wait (0 for no timeout)
/// @param error Error pointer
/// @return The fulfilled value or nil
- (nullable ValueType)waitWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;

/// Wait for the future to complete
/// @return The fulfilled value or nil
- (nullable ValueType)wait;

@end

// MARK: - Convenience Categories

@interface PKFuture (Convenience)

/// Create a future that fulfills after a delay
/// @param delay Delay in seconds
/// @param value Value to fulfill with
+ (PKFuture *)after:(NSTimeInterval)delay value:(nullable id)value;

/// Create a future from a block
/// @param block Block to execute
+ (PKFuture *)fromBlock:(id _Nullable (^)(void))block;

/// Create a future from an async operation
/// @param operation Async operation with completion handler
+ (PKFuture *)fromAsync:(void (^)(void (^completion)(id _Nullable value, NSError * _Nullable error)))operation;

/// Zip two futures together
/// @param other Other future
/// @return Future with tuple of both values
- (PKFuture<NSArray *> *)zip:(PKFuture *)other;

@end

// MARK: - Error Domain

FOUNDATION_EXPORT NSErrorDomain const PKFutureErrorDomain;

typedef NS_ERROR_ENUM(PKFutureErrorDomain, PKFutureError) {
    PKFutureErrorTimeout = 1000,
    PKFutureErrorFiltered = 1001,
    PKFutureErrorCancelled = 1002,
    PKFutureErrorInvalidState = 1003,
    PKFutureErrorNoValue = 1004
};

NS_ASSUME_NONNULL_END
