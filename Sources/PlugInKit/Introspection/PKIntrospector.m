//
//  PKIntrospector.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKIntrospector.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"
#import "../Core/PKConnection.h"

@implementation PKIntrospectionResult

- (instancetype)initWithPlugInIdentifier:(NSString *)identifier
                                 methods:(NSArray<PKMethodMetadata *> *)methods
                            capabilities:(NSDictionary<NSString *, id> *)capabilities {
    if (self = [super init]) {
        _plugInIdentifier = [identifier copy];
        _methods = [methods copy];
        _capabilities = [capabilities copy];
        _timestamp = [NSDate date];
    }
    return self;
}

- (NSArray<PKMethodMetadata *> *)methodsWithExposureOptions:(NSUInteger)options {
    NSMutableArray<PKMethodMetadata *> *filtered = [NSMutableArray array];

    for (PKMethodMetadata *method in self.methods) {
        if (method.exposureOptions & options) {
            [filtered addObject:method];
        }
    }

    return [filtered copy];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PKIntrospectionResult: %@ - %lu methods>",
            self.plugInIdentifier, (unsigned long)self.methods.count];
}

@end

@implementation PKIntrospector

+ (void)introspectConnection:(PKConnection *)connection
                  completion:(void (^)(PKIntrospectionResult * _Nullable result, NSError * _Nullable error))completion {
    id<PKPlugInProtocol> plugin = [connection remotePlugInWithErrorHandler:^(NSError *error) {
        if (completion) {
            completion(nil, error);
        }
    }];

    // Fetch methods
    [plugin exposedMethodsWithReply:^(NSArray<PKMethodMetadata *> * _Nonnull methods) {
        // Fetch capabilities if supported
        if ([plugin respondsToSelector:@selector(capabilitiesWithReply:)]) {
            [plugin capabilitiesWithReply:^(NSDictionary<NSString *,id> * _Nonnull capabilities) {
                PKIntrospectionResult *result = [[PKIntrospectionResult alloc] initWithPlugInIdentifier:connection.plugInIdentifier
                                                                                                 methods:methods
                                                                                            capabilities:capabilities];
                if (completion) {
                    completion(result, nil);
                }
            }];
        } else {
            PKIntrospectionResult *result = [[PKIntrospectionResult alloc] initWithPlugInIdentifier:connection.plugInIdentifier
                                                                                             methods:methods
                                                                                        capabilities:@{}];
            if (completion) {
                completion(result, nil);
            }
        }
    }];
}

+ (void)introspectConnections:(NSArray<PKConnection *> *)connections
                   completion:(void (^)(NSArray<PKIntrospectionResult *> *results, NSError * _Nullable error))completion {
    if (connections.count == 0) {
        if (completion) {
            completion(@[], nil);
        }
        return;
    }

    NSMutableArray<PKIntrospectionResult *> *results = [NSMutableArray arrayWithCapacity:connections.count];
    dispatch_group_t group = dispatch_group_create();

    for (PKConnection *connection in connections) {
        dispatch_group_enter(group);

        [self introspectConnection:connection completion:^(PKIntrospectionResult * _Nullable result, NSError * _Nullable error) {
            if (result) {
                @synchronized (results) {
                    [results addObject:result];
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion([results copy], nil);
        }
    });
}

+ (NSString *)signatureForMethod:(PKMethodMetadata *)metadata {
    NSMutableString *signature = [NSMutableString stringWithString:metadata.selector];

    if (metadata.parameterTypes.count > 0) {
        [signature appendString:@"("];
        [signature appendString:[metadata.parameterTypes componentsJoinedByString:@", "]];
        [signature appendString:@")"];
    }

    [signature appendFormat:@" -> %@", metadata.returnType];

    return [signature copy];
}

+ (NSDictionary<NSString *, id> *)analyzeReturnType:(PKMethodMetadata *)metadata {
    NSString *returnType = metadata.returnType;

    // Parse Objective-C type encoding
    BOOL isVoid = [returnType isEqualToString:@"v"];
    BOOL isObject = [returnType hasPrefix:@"@"];
    BOOL isPrimitive = !isVoid && !isObject;

    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    analysis[@"typeString"] = returnType;
    analysis[@"isVoid"] = @(isVoid);
    analysis[@"isObject"] = @(isObject);
    analysis[@"isPrimitive"] = @(isPrimitive);

    if (isObject) {
        // Try to extract class name from type encoding like @"NSString"
        NSRange quoteRange = [returnType rangeOfString:@"\""];
        if (quoteRange.location != NSNotFound) {
            NSString *className = [returnType substringFromIndex:quoteRange.location + 1];
            NSRange endQuote = [className rangeOfString:@"\""];
            if (endQuote.location != NSNotFound) {
                className = [className substringToIndex:endQuote.location];
                analysis[@"className"] = className;
            }
        }
    }

    return [analysis copy];
}

+ (NSArray<NSDictionary<NSString *, id> *> *)analyzeParameters:(PKMethodMetadata *)metadata {
    NSMutableArray<NSDictionary<NSString *, id> *> *parameters = [NSMutableArray array];

    for (NSUInteger i = 0; i < metadata.parameterTypes.count; i++) {
        NSString *paramType = metadata.parameterTypes[i];

        NSMutableDictionary *paramInfo = [NSMutableDictionary dictionary];
        paramInfo[@"index"] = @(i);
        paramInfo[@"typeString"] = paramType;

        BOOL isObject = [paramType hasPrefix:@"@"];
        BOOL isPrimitive = !isObject;

        paramInfo[@"isObject"] = @(isObject);
        paramInfo[@"isPrimitive"] = @(isPrimitive);

        if (isObject) {
            NSRange quoteRange = [paramType rangeOfString:@"\""];
            if (quoteRange.location != NSNotFound) {
                NSString *className = [paramType substringFromIndex:quoteRange.location + 1];
                NSRange endQuote = [className rangeOfString:@"\""];
                if (endQuote.location != NSNotFound) {
                    className = [className substringToIndex:endQuote.location];
                    paramInfo[@"className"] = className;
                }
            }
        }

        [parameters addObject:[paramInfo copy]];
    }

    return [parameters copy];
}

@end
