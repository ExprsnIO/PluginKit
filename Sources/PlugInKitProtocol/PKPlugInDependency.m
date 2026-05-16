//
//  PKPlugInDependency.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInDependency.h"

@implementation PKPlugInDependency

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                    minimumVersion:(nullable NSString *)minimumVersion
                    maximumVersion:(nullable NSString *)maximumVersion
                          optional:(BOOL)optional {
    if (self = [super init]) {
        _identifier = [identifier copy];
        _minimumVersion = [minimumVersion copy];
        _maximumVersion = [maximumVersion copy];
        _optional = optional;
    }
    return self;
}

+ (nullable instancetype)dependencyWithDictionary:(NSDictionary *)dictionary {
    NSString *identifier = dictionary[@"identifier"];
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        return nil;
    }

    NSString *minimumVersion = dictionary[@"minimumVersion"];
    if (![minimumVersion isKindOfClass:[NSString class]]) {
        minimumVersion = nil;
    }

    NSString *maximumVersion = dictionary[@"maximumVersion"];
    if (![maximumVersion isKindOfClass:[NSString class]]) {
        maximumVersion = nil;
    }

    BOOL optional = NO;
    id optionalValue = dictionary[@"optional"];
    if ([optionalValue respondsToSelector:@selector(boolValue)]) {
        optional = [optionalValue boolValue];
    }

    return [[self alloc] initWithIdentifier:identifier
                             minimumVersion:minimumVersion
                             maximumVersion:maximumVersion
                                   optional:optional];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_minimumVersion forKey:@"minimumVersion"];
    [coder encodeObject:_maximumVersion forKey:@"maximumVersion"];
    [coder encodeBool:_optional forKey:@"optional"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
    NSString *minimumVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"minimumVersion"];
    NSString *maximumVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"maximumVersion"];
    BOOL optional = [coder decodeBoolForKey:@"optional"];

    if (identifier.length == 0) {
        return nil;
    }

    return [self initWithIdentifier:identifier
                     minimumVersion:minimumVersion
                     maximumVersion:maximumVersion
                           optional:optional];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PKPlugInDependency: %@ min=%@ max=%@ optional=%@>",
            self.identifier, self.minimumVersion ?: @"-", self.maximumVersion ?: @"-",
            self.optional ? @"YES" : @"NO"];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[PKPlugInDependency class]]) return NO;

    PKPlugInDependency *other = (PKPlugInDependency *)object;
    return [self.identifier isEqualToString:other.identifier] &&
           (self.minimumVersion == other.minimumVersion ||
            [self.minimumVersion isEqualToString:other.minimumVersion]) &&
           (self.maximumVersion == other.maximumVersion ||
            [self.maximumVersion isEqualToString:other.maximumVersion]) &&
           self.optional == other.optional;
}

- (NSUInteger)hash {
    return self.identifier.hash;
}

@end
