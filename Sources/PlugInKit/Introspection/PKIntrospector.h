//
//  PKIntrospector.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PKMethodMetadata, PKConnection;

/// Result of method introspection
@interface PKIntrospectionResult : NSObject

@property (nonatomic, copy, readonly) NSString *plugInIdentifier;
@property (nonatomic, copy, readonly) NSArray<PKMethodMetadata *> *methods;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *capabilities;
@property (nonatomic, strong, readonly) NSDate *timestamp;

- (instancetype)initWithPlugInIdentifier:(NSString *)identifier
                                 methods:(NSArray<PKMethodMetadata *> *)methods
                            capabilities:(NSDictionary<NSString *, id> *)capabilities;

/// Filter methods by exposure options
/// @param options Exposure options to filter by
/// @return Filtered array of methods
- (NSArray<PKMethodMetadata *> *)methodsWithExposureOptions:(NSUInteger)options;

@end

/// Introspector for analyzing plugin capabilities and methods
@interface PKIntrospector : NSObject

/// Introspect a plugin connection
/// @param connection Plugin connection
/// @param completion Completion handler with introspection result
+ (void)introspectConnection:(PKConnection *)connection
                  completion:(void (^)(PKIntrospectionResult * _Nullable result, NSError * _Nullable error))completion;

/// Introspect multiple connections
/// @param connections Array of connections
/// @param completion Completion handler with results
+ (void)introspectConnections:(NSArray<PKConnection *> *)connections
                   completion:(void (^)(NSArray<PKIntrospectionResult *> *results, NSError * _Nullable error))completion;

/// Generate method signature string
/// @param metadata Method metadata
/// @return Method signature string
+ (NSString *)signatureForMethod:(PKMethodMetadata *)metadata;

/// Analyze method return type
/// @param metadata Method metadata
/// @return Dictionary with type information
+ (NSDictionary<NSString *, id> *)analyzeReturnType:(PKMethodMetadata *)metadata;

/// Analyze method parameters
/// @param metadata Method metadata
/// @return Array of parameter information dictionaries
+ (NSArray<NSDictionary<NSString *, id> *> *)analyzeParameters:(PKMethodMetadata *)metadata;

@end

NS_ASSUME_NONNULL_END
