//
//  PKCancellationToken.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Token for cancelling asynchronous operations
@interface PKCancellationToken : NSObject

/// Whether this token has been cancelled
@property (nonatomic, assign, readonly) BOOL isCancelled;

/// Cancel the operation associated with this token
- (void)cancel;

/// Register a callback to be invoked when cancelled
/// @param handler Block to execute on cancellation
- (void)onCancelled:(void (^)(void))handler;

/// Create a linked token that cancels when any parent cancels
/// @param tokens Array of parent tokens
+ (instancetype)linkedTokenWithTokens:(NSArray<PKCancellationToken *> *)tokens;

@end

NS_ASSUME_NONNULL_END
