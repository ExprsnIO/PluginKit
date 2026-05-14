//
//  PKPlugInManager+Dependencies.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInManager+Dependencies.h"
#import "PKPlugInManager+Compatibility.h"
#import "PKConnection.h"
#import "PKError.h"
#import "PKLogger.h"
#import "PKCancellationToken.h"
#import "../../PlugInKitProtocol/PKPlugInDependency.h"

@implementation PKPlugInManager (Dependencies)

// MARK: - Version Satisfaction

- (BOOL)pk_dependency:(PKPlugInDependency *)dependency satisfiedByVersion:(NSString *)version {
    if (dependency.minimumVersion &&
        [PKPlugInManager compareVersion:version toVersion:dependency.minimumVersion] == NSOrderedAscending) {
        return NO;
    }
    if (dependency.maximumVersion &&
        [PKPlugInManager compareVersion:version toVersion:dependency.maximumVersion] == NSOrderedDescending) {
        return NO;
    }
    return YES;
}

// MARK: - Load Order

- (nullable NSArray<NSString *> *)loadOrderForPlugIns:(NSArray<NSString *> *)identifiers
                                                error:(NSError **)error {
    id<PKPlugInManagerDependencyDelegate> delegate =
        (id<PKPlugInManagerDependencyDelegate>)self.dependencyDelegate;

    // edges[dependency] = set of dependents; inDegree[node] = number of unmet deps.
    NSMutableSet<NSString *> *nodes = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *edges = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *inDegree = [NSMutableDictionary dictionary];

    NSMutableArray<NSString *> *queue = [identifiers mutableCopy];

    while (queue.count > 0) {
        NSString *identifier = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([nodes containsObject:identifier]) {
            continue;
        }

        PKPlugInInfo *info = [self plugInInfoForIdentifier:identifier];
        if (!info) {
            if (error) {
                *error = [NSError pk_errorWithCode:PKErrorMissingDependency
                                       description:[NSString stringWithFormat:
                                                    @"Plugin '%@' is not discovered", identifier]
                                          userInfo:@{PKErrorPlugInIdentifierKey: identifier}];
            }
            return nil;
        }

        [nodes addObject:identifier];
        if (inDegree[identifier] == nil) {
            inDegree[identifier] = @0;
        }

        for (PKPlugInDependency *dependency in info.requiredPlugins) {
            NSString *depID = dependency.identifier;
            PKPlugInInfo *depInfo = [self plugInInfoForIdentifier:depID];

            if (!depInfo) {
                if (dependency.isOptional) {
                    NSString *reason = @"dependency is not discovered";
                    if ([delegate respondsToSelector:@selector(plugInManager:didSkipOptionalDependency:reason:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [delegate plugInManager:self didSkipOptionalDependency:depID reason:reason];
                        });
                    }
                    continue;
                }
                if (error) {
                    *error = [NSError pk_errorWithCode:PKErrorMissingDependency
                                           description:[NSString stringWithFormat:
                                                        @"Plugin '%@' requires missing dependency '%@'",
                                                        identifier, depID]
                                              userInfo:@{
                                                  PKErrorPlugInIdentifierKey: identifier,
                                                  PKErrorDependencyChainKey: @[identifier, depID],
                                              }];
                }
                return nil;
            }

            if (![self pk_dependency:dependency satisfiedByVersion:depInfo.version]) {
                if (dependency.isOptional) {
                    NSString *reason = [NSString stringWithFormat:
                                        @"dependency version %@ does not satisfy constraints", depInfo.version];
                    if ([delegate respondsToSelector:@selector(plugInManager:didSkipOptionalDependency:reason:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [delegate plugInManager:self didSkipOptionalDependency:depID reason:reason];
                        });
                    }
                    continue;
                }
                if (error) {
                    *error = [NSError pk_errorWithCode:PKErrorDependencyVersionMismatch
                                           description:[NSString stringWithFormat:
                                                        @"Plugin '%@' requires '%@' version %@-%@, found %@",
                                                        identifier, depID,
                                                        dependency.minimumVersion ?: @"any",
                                                        dependency.maximumVersion ?: @"any",
                                                        depInfo.version]
                                              userInfo:@{
                                                  PKErrorPlugInIdentifierKey: identifier,
                                                  PKErrorActualVersionKey: depInfo.version,
                                              }];
                }
                return nil;
            }

            // Edge: depID must precede identifier.
            NSMutableSet<NSString *> *dependents = edges[depID];
            if (!dependents) {
                dependents = [NSMutableSet set];
                edges[depID] = dependents;
            }
            if (![dependents containsObject:identifier]) {
                [dependents addObject:identifier];
                inDegree[identifier] = @(inDegree[identifier].integerValue + 1);
            }

            if (![nodes containsObject:depID]) {
                [queue addObject:depID];
            }
        }
    }

    // Kahn's algorithm for a deterministic topological order.
    NSMutableDictionary<NSString *, NSNumber *> *workingInDegree = [inDegree mutableCopy];
    NSMutableArray<NSString *> *ready = [NSMutableArray array];
    for (NSString *node in nodes) {
        if (workingInDegree[node].integerValue == 0) {
            [ready addObject:node];
        }
    }
    [ready sortUsingSelector:@selector(compare:)];

    NSMutableArray<NSString *> *result = [NSMutableArray array];
    while (ready.count > 0) {
        NSString *node = ready.firstObject;
        [ready removeObjectAtIndex:0];
        [result addObject:node];

        NSArray<NSString *> *dependents = [edges[node].allObjects
                                           sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *dependent in dependents) {
            NSInteger remaining = workingInDegree[dependent].integerValue - 1;
            workingInDegree[dependent] = @(remaining);
            if (remaining == 0) {
                [ready addObject:dependent];
            }
        }
        [ready sortUsingSelector:@selector(compare:)];
    }

    if (result.count < nodes.count) {
        NSMutableArray<NSString *> *cycle = [NSMutableArray array];
        for (NSString *node in nodes) {
            if (workingInDegree[node].integerValue > 0) {
                [cycle addObject:node];
            }
        }
        [cycle sortUsingSelector:@selector(compare:)];

        if (error) {
            *error = [NSError pk_errorWithCode:PKErrorCircularDependency
                                   description:[NSString stringWithFormat:
                                                @"Circular dependency detected among: %@",
                                                [cycle componentsJoinedByString:@", "]]
                                      userInfo:@{PKErrorDependencyChainKey: [cycle copy]}];
        }
        return nil;
    }

    return [result copy];
}

// MARK: - Ordered Connection

- (void)connectAllWithDependencyResolutionWithCompletion:
    (void (^)(NSDictionary<NSString *, PKConnection *> *connected,
              NSArray<NSError *> *errors))completion {
    [self connectAllWithDependencyResolutionCancellationToken:nil completion:completion];
}

- (void)connectAllWithDependencyResolutionCancellationToken:(nullable PKCancellationToken *)token
                                                 completion:
    (void (^)(NSDictionary<NSString *, PKConnection *> *connected,
              NSArray<NSError *> *errors))completion {
    PKLogger *logger = [PKLogger loggerWithCategory:@"Dependencies"];

    [self discoverPlugInsWithCompletion:^(NSArray<PKPlugInInfo *> *plugIns, NSError *discoverError) {
        NSMutableArray<NSError *> *errors = [NSMutableArray array];
        if (discoverError) {
            [errors addObject:discoverError];
        }

        NSMutableArray<NSString *> *allIdentifiers = [NSMutableArray array];
        for (PKPlugInInfo *info in plugIns) {
            [allIdentifiers addObject:info.identifier];
        }

        NSError *orderError = nil;
        NSArray<NSString *> *order = [self loadOrderForPlugIns:allIdentifiers error:&orderError];
        if (!order) {
            if (orderError) {
                [errors addObject:orderError];
            }
            [logger error:@"Dependency resolution failed: %@", orderError.localizedDescription];
            if (completion) {
                completion(@{}, [errors copy]);
            }
            return;
        }

        [logger info:@"Connecting %lu plugin(s) in dependency order", (unsigned long)order.count];
        [self pk_connectInOrder:order
                          index:0
                          token:token
                      connected:[NSMutableDictionary dictionary]
                         errors:errors
                     completion:completion];
    }];
}

- (void)pk_connectInOrder:(NSArray<NSString *> *)order
                    index:(NSUInteger)index
                    token:(nullable PKCancellationToken *)token
                connected:(NSMutableDictionary<NSString *, PKConnection *> *)connected
                   errors:(NSMutableArray<NSError *> *)errors
               completion:(void (^)(NSDictionary<NSString *, PKConnection *> *connected,
                                    NSArray<NSError *> *errors))completion {
    if (index >= order.count) {
        if (completion) {
            completion([connected copy], [errors copy]);
        }
        return;
    }

    if (token.isCancelled) {
        [errors addObject:[NSError pk_errorWithCode:PKErrorOperationCancelled
                                        description:@"Dependency resolution was cancelled"]];
        if (completion) {
            completion([connected copy], [errors copy]);
        }
        return;
    }

    NSString *identifier = order[index];

    // If a later plugin in the order requires this one, announce it as a dependency.
    id<PKPlugInManagerDependencyDelegate> delegate =
        (id<PKPlugInManagerDependencyDelegate>)self.dependencyDelegate;
    if ([delegate respondsToSelector:@selector(plugInManager:willConnectPlugIn:becauseRequiredBy:)]) {
        for (NSUInteger i = index + 1; i < order.count; i++) {
            PKPlugInInfo *candidate = [self plugInInfoForIdentifier:order[i]];
            BOOL requiresIt = NO;
            for (PKPlugInDependency *dependency in candidate.requiredPlugins) {
                if ([dependency.identifier isEqualToString:identifier]) {
                    requiresIt = YES;
                    break;
                }
            }
            if (requiresIt) {
                NSString *dependent = order[i];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate plugInManager:self willConnectPlugIn:identifier becauseRequiredBy:dependent];
                });
                break;
            }
        }
    }

    [self connectToPlugIn:identifier configuration:nil completion:^(PKConnection *connection, NSError *error) {
        if (connection) {
            connected[identifier] = connection;
        } else if (error) {
            [errors addObject:error];
        }

        [self pk_connectInOrder:order
                          index:index + 1
                          token:token
                      connected:connected
                         errors:errors
                     completion:completion];
    }];
}

@end
