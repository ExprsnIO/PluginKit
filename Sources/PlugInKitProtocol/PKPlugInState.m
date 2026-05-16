//
//  PKPlugInState.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInState.h"

@implementation PKPlugInState

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                           payload:(NSDictionary<NSString *, id<NSSecureCoding>> *)payload {
    if (self = [super init]) {
        _identifier = [identifier copy];
        _version = [version copy];
        _capturedAt = [NSDate date];
        _payload = [payload copy] ?: @{};
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                           version:(NSString *)version
                        capturedAt:(NSDate *)capturedAt
                           payload:(NSDictionary<NSString *, id<NSSecureCoding>> *)payload {
    if (self = [super init]) {
        _identifier = [identifier copy];
        _version = [version copy];
        _capturedAt = [capturedAt copy] ?: [NSDate date];
        _payload = [payload copy] ?: @{};
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_version forKey:@"version"];
    [coder encodeObject:_capturedAt forKey:@"capturedAt"];
    [coder encodeObject:_payload forKey:@"payload"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
    NSString *version = [coder decodeObjectOfClass:[NSString class] forKey:@"version"];
    NSDate *capturedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"capturedAt"];

    // The payload may contain arbitrary plugin-defined value types; allow the
    // common property-list classes plus collections.
    NSSet *payloadClasses = [NSSet setWithObjects:
                             [NSDictionary class], [NSArray class], [NSString class],
                             [NSNumber class], [NSDate class], [NSData class],
                             [NSNull class], nil];
    NSDictionary *payload = [coder decodeObjectOfClasses:payloadClasses forKey:@"payload"];

    return [self initWithIdentifier:identifier ?: @""
                            version:version ?: @""
                         capturedAt:capturedAt
                            payload:payload];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PKPlugInState: %@ v%@ capturedAt=%@ keys=%lu>",
            self.identifier, self.version, self.capturedAt,
            (unsigned long)self.payload.count];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[PKPlugInState class]]) return NO;

    PKPlugInState *other = (PKPlugInState *)object;
    return [self.identifier isEqualToString:other.identifier] &&
           [self.version isEqualToString:other.version] &&
           [self.payload isEqualToDictionary:other.payload];
}

- (NSUInteger)hash {
    return self.identifier.hash ^ self.version.hash ^ self.payload.hash;
}

@end
