//
//  PKFuture+Cancellation.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PKFuture.h"
#import "PKCancellationToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface PKFuture (Cancellation)

/// Cancellation token for this future
@property (nonatomic, strong, readonly) PKCancellationToken *cancellationToken;

/// Cancel this future and reject with cancellation error
- (void)cancel;

/// Attach a cancellation token to this future
/// @param token Token to attach
/// @return New future that cancels when token cancels
- (PKFuture *)attachCancellationToken:(PKCancellationToken *)token;

/// Execute a block when this future is cancelled
/// @param handler Block to execute on cancellation
/// @return Same future for chaining
- (PKFuture *)onCancelled:(void (^)(void))handler;

/// Create a future with a cancellation token
/// @param resolver Resolver block
/// @param token Cancellation token
+ (instancetype)futureWithResolver:(void (^)(void (^fulfill)(id _Nullable value),
                                             void (^reject)(NSError *error),
                                             PKCancellationToken *token))resolver
                 cancellationToken:(PKCancellationToken *)token;

@end

NS_ASSUME_NONNULL_END
