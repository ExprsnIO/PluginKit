//
//  PKPlugInProtocol.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKPlugInProtocol.h"

@implementation PKMethodMetadata

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithSelector:(NSString *)selector
                     displayName:(NSString *)displayName
                     description:(nullable NSString *)description
                 exposureOptions:(PKMethodExposureOptions)options
                  parameterTypes:(NSArray<NSString *> *)parameterTypes
                      returnType:(NSString *)returnType {
    if (self = [super init]) {
        _selector = [selector copy];
        _displayName = [displayName copy];
        _methodDescription = [description copy];
        _exposureOptions = options;
        _parameterTypes = [parameterTypes copy];
        _returnType = [returnType copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_selector forKey:@"selector"];
    [coder encodeObject:_displayName forKey:@"displayName"];
    [coder encodeObject:_methodDescription forKey:@"methodDescription"];
    [coder encodeInteger:_exposureOptions forKey:@"exposureOptions"];
    [coder encodeObject:_parameterTypes forKey:@"parameterTypes"];
    [coder encodeObject:_returnType forKey:@"returnType"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSString *selector = [coder decodeObjectOfClass:[NSString class] forKey:@"selector"];
    NSString *displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
    NSString *methodDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"methodDescription"];
    PKMethodExposureOptions exposureOptions = [coder decodeIntegerForKey:@"exposureOptions"];
    NSArray<NSString *> *parameterTypes = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:@"parameterTypes"];
    NSString *returnType = [coder decodeObjectOfClass:[NSString class] forKey:@"returnType"];

    return [self initWithSelector:selector
                      displayName:displayName
                      description:methodDescription
                  exposureOptions:exposureOptions
                   parameterTypes:parameterTypes
                       returnType:returnType];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PKMethodMetadata: %@ (%@) exposure=%lu>",
            self.displayName, self.selector, (unsigned long)self.exposureOptions];
}

@end
