//
//  PKScriptingDefinitionGenerator.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import "PKScriptingDefinitionGenerator.h"
#import "../Introspection/PKIntrospector.h"
#import "../../PlugInKitProtocol/PKPlugInProtocol.h"

@implementation PKScriptingDefinitionGenerator

+ (NSString *)generateDefinitionFromIntrospectionResult:(PKIntrospectionResult *)result
                                                 format:(PKScriptingDefinitionFormat)format
                                                options:(PKScriptingDefinitionOptions)options {
    switch (format) {
        case PKScriptingDefinitionFormatAppleScript:
            return [self generateAppleScriptDefinition:result options:options];

        case PKScriptingDefinitionFormatJavaScript:
            return [self generateJavaScriptDefinition:result options:options];

        case PKScriptingDefinitionFormatSDEF:
            return [self generateSDEFFromIntrospectionResults:@[result]
                                                    suiteName:result.plugInIdentifier
                                                      options:options];
    }
}

+ (NSString *)generateSDEFFromIntrospectionResults:(NSArray<PKIntrospectionResult *> *)results
                                         suiteName:(NSString *)suiteName
                                           options:(PKScriptingDefinitionOptions)options {
    NSMutableString *sdef = [NSMutableString string];

    [sdef appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
    [sdef appendString:@"<!DOCTYPE dictionary SYSTEM \"file://localhost/System/Library/DTDs/sdef.dtd\">\n"];
    [sdef appendFormat:@"<dictionary title=\"%@ Scripting\">\n", suiteName];
    [sdef appendFormat:@"  <suite name=\"%@ Suite\" code=\"PKIt\" description=\"Commands and classes for %@\">\n", suiteName, suiteName];

    for (PKIntrospectionResult *result in results) {
        BOOL includePrivate = (options & PKScriptingDefinitionOptionsIncludePrivate) != 0;

        NSArray<PKMethodMetadata *> *methods = result.methods;
        if (!includePrivate) {
            methods = [result methodsWithExposureOptions:PKMethodExposureAll];
        }

        for (PKMethodMetadata *method in methods) {
            BOOL exposeToAppleScript = (method.exposureOptions & PKMethodExposureAppleScript) != 0;

            if (!exposeToAppleScript && !includePrivate) {
                continue;
            }

            // Generate command entry
            NSString *commandName = [self appleScriptNameFromSelector:method.selector];
            NSString *commandCode = [self generateFourCharCode:method.selector];

            [sdef appendFormat:@"    <command name=\"%@\" code=\"%@\" description=\"%@\">\n",
             commandName, commandCode, method.methodDescription ?: @""];

            // Add parameters
            NSArray<NSDictionary *> *params = [PKIntrospector analyzeParameters:method];
            for (NSUInteger i = 0; i < params.count; i++) {
                NSDictionary *param = params[i];
                NSString *paramName = [NSString stringWithFormat:@"parameter%lu", (unsigned long)(i + 1)];
                NSString *paramCode = [NSString stringWithFormat:@"par%lu", (unsigned long)(i + 1)];
                NSString *paramType = [self sdefTypeFromObjCType:param[@"typeString"]];

                [sdef appendFormat:@"      <parameter name=\"%@\" code=\"%@\" type=\"%@\" description=\"Parameter %lu\">\n",
                 paramName, paramCode, paramType, (unsigned long)(i + 1)];
                [sdef appendString:@"        <cocoa key=\"\"/>\n"];
                [sdef appendString:@"      </parameter>\n"];
            }

            // Add result
            NSDictionary *returnInfo = [PKIntrospector analyzeReturnType:method];
            if (![returnInfo[@"isVoid"] boolValue]) {
                NSString *resultType = [self sdefTypeFromObjCType:method.returnType];
                [sdef appendFormat:@"      <result type=\"%@\" description=\"Return value\"/>\n", resultType];
            }

            [sdef appendString:@"    </command>\n"];
        }
    }

    [sdef appendString:@"  </suite>\n"];
    [sdef appendString:@"</dictionary>\n"];

    return [sdef copy];
}

+ (NSString *)generateAppleScriptDefinition:(PKIntrospectionResult *)result
                                    options:(PKScriptingDefinitionOptions)options {
    NSMutableString *definition = [NSMutableString string];
    BOOL includePrivate = (options & PKScriptingDefinitionOptionsIncludePrivate) != 0;
    BOOL verbose = (options & PKScriptingDefinitionOptionsVerbose) != 0;

    [definition appendFormat:@"-- AppleScript Scripting Definition for %@\n", result.plugInIdentifier];
    [definition appendFormat:@"-- Generated: %@\n\n", [NSDate date]];

    NSArray<PKMethodMetadata *> *methods = result.methods;
    if (!includePrivate) {
        methods = [result methodsWithExposureOptions:PKMethodExposureAppleScript];
    }

    [definition appendFormat:@"tell application \"System Events\"\n"];
    [definition appendFormat:@"  -- Plugin: %@\n", result.plugInIdentifier];
    [definition appendFormat:@"  -- Available commands: %lu\n\n", (unsigned long)methods.count];

    for (PKMethodMetadata *method in methods) {
        NSString *commandName = [self appleScriptNameFromSelector:method.selector];

        [definition appendFormat:@"  -- %@\n", method.displayName];

        if (verbose && method.methodDescription) {
            [definition appendFormat:@"  -- %@\n", method.methodDescription];
        }

        [definition appendFormat:@"  -- Usage: %@", commandName];

        NSArray<NSDictionary *> *params = [PKIntrospector analyzeParameters:method];
        if (params.count > 0) {
            for (NSUInteger i = 0; i < params.count; i++) {
                [definition appendFormat:@" parameter%lu:<value>", (unsigned long)(i + 1)];
            }
        }

        [definition appendString:@"\n"];

        NSDictionary *returnInfo = [PKIntrospector analyzeReturnType:method];
        if (![returnInfo[@"isVoid"] boolValue]) {
            [definition appendFormat:@"  -- Returns: %@\n", returnInfo[@"typeString"]];
        }

        [definition appendString:@"\n"];
    }

    [definition appendString:@"end tell\n"];

    return [definition copy];
}

+ (NSString *)generateJavaScriptDefinition:(PKIntrospectionResult *)result
                                   options:(PKScriptingDefinitionOptions)options {
    NSMutableString *definition = [NSMutableString string];
    BOOL includePrivate = (options & PKScriptingDefinitionOptionsIncludePrivate) != 0;
    BOOL includeTypes = (options & PKScriptingDefinitionOptionsIncludeTypes) != 0;

    [definition appendFormat:@"// JavaScript for Automation (JXA) Definition for %@\n", result.plugInIdentifier];
    [definition appendFormat:@"// Generated: %@\n\n", [NSDate date]];

    NSArray<PKMethodMetadata *> *methods = result.methods;
    if (!includePrivate) {
        methods = [result methodsWithExposureOptions:PKMethodExposureJavaScript];
    }

    [definition appendFormat:@"const %@ = {\n", [self jsIdentifierFromString:result.plugInIdentifier]];

    for (NSUInteger methodIdx = 0; methodIdx < methods.count; methodIdx++) {
        PKMethodMetadata *method = methods[methodIdx];
        NSString *methodName = [self jsMethodNameFromSelector:method.selector];

        [definition appendFormat:@"  /**\n"];
        [definition appendFormat:@"   * %@\n", method.displayName];

        if (method.methodDescription) {
            [definition appendFormat:@"   * %@\n", method.methodDescription];
        }

        NSArray<NSDictionary *> *params = [PKIntrospector analyzeParameters:method];
        for (NSUInteger i = 0; i < params.count; i++) {
            NSDictionary *param = params[i];
            NSString *jsType = includeTypes ? [self jsTypeFromObjCType:param[@"typeString"]] : @"*";
            [definition appendFormat:@"   * @param {%@} param%lu - Parameter %lu\n",
             jsType, (unsigned long)(i + 1), (unsigned long)(i + 1)];
        }

        NSDictionary *returnInfo = [PKIntrospector analyzeReturnType:method];
        if (![returnInfo[@"isVoid"] boolValue]) {
            NSString *returnType = includeTypes ? [self jsTypeFromObjCType:method.returnType] : @"*";
            [definition appendFormat:@"   * @returns {%@}\n", returnType];
        }

        [definition appendFormat:@"   */\n"];

        // Generate method signature
        [definition appendFormat:@"  %@: function(", methodName];

        for (NSUInteger i = 0; i < params.count; i++) {
            if (i > 0) [definition appendString:@", "];
            [definition appendFormat:@"param%lu", (unsigned long)(i + 1)];
        }

        [definition appendString:@") {\n"];
        [definition appendString:@"    // Implementation provided by plugin\n"];
        [definition appendString:@"  }"];

        if (methodIdx < methods.count - 1) {
            [definition appendString:@","];
        }

        [definition appendString:@"\n\n"];
    }

    [definition appendString:@"};\n"];

    return [definition copy];
}

+ (BOOL)exportDefinition:(NSString *)definition
                   toURL:(NSURL *)url
                   error:(NSError **)error {
    return [definition writeToURL:url
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:error];
}

#pragma mark - Helper Methods

+ (NSString *)appleScriptNameFromSelector:(NSString *)selector {
    // Convert selector to AppleScript-friendly name
    // e.g., "processData:withOptions:" -> "process data with options"
    NSString *name = [selector stringByReplacingOccurrencesOfString:@":" withString:@" "];
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    // Insert spaces before capital letters
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        if (i > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c]) {
            [result appendString:@" "];
        }
        [result appendFormat:@"%C", c];
    }

    return [[result lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString *)jsMethodNameFromSelector:(NSString *)selector {
    // Convert selector to JavaScript method name
    // e.g., "processData:withOptions:" -> "processDataWithOptions"
    NSArray *components = [selector componentsSeparatedByString:@":"];
    NSMutableString *result = [NSMutableString stringWithString:components[0]];

    for (NSUInteger i = 1; i < components.count; i++) {
        NSString *component = components[i];
        if (component.length > 0) {
            NSString *capitalized = [component stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                                       withString:[[component substringToIndex:1] uppercaseString]];
            [result appendString:capitalized];
        }
    }

    return [result copy];
}

+ (NSString *)jsIdentifierFromString:(NSString *)string {
    // Convert bundle identifier to JS identifier
    // e.g., "com.example.plugin" -> "comExamplePlugin"
    NSArray *components = [string componentsSeparatedByString:@"."];
    NSMutableString *result = [NSMutableString stringWithString:components[0]];

    for (NSUInteger i = 1; i < components.count; i++) {
        NSString *component = components[i];
        if (component.length > 0) {
            NSString *capitalized = [component stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                                       withString:[[component substringToIndex:1] uppercaseString]];
            [result appendString:capitalized];
        }
    }

    return [result copy];
}

+ (NSString *)generateFourCharCode:(NSString *)string {
    // Generate a four-character code for AppleScript
    if (string.length >= 4) {
        return [string substringToIndex:4];
    } else {
        return [string stringByPaddingToLength:4 withString:@"_" startingAtIndex:0];
    }
}

+ (NSString *)sdefTypeFromObjCType:(NSString *)objcType {
    if ([objcType hasPrefix:@"@"]) {
        if ([objcType containsString:@"NSString"]) return @"text";
        if ([objcType containsString:@"NSNumber"]) return @"number";
        if ([objcType containsString:@"NSArray"]) return @"list";
        if ([objcType containsString:@"NSDictionary"]) return @"record";
        return @"any";
    }

    if ([objcType isEqualToString:@"i"] || [objcType isEqualToString:@"l"] ||
        [objcType isEqualToString:@"q"]) return @"integer";
    if ([objcType isEqualToString:@"f"] || [objcType isEqualToString:@"d"]) return @"real";
    if ([objcType isEqualToString:@"B"] || [objcType isEqualToString:@"c"]) return @"boolean";

    return @"any";
}

+ (NSString *)jsTypeFromObjCType:(NSString *)objcType {
    if ([objcType hasPrefix:@"@"]) {
        if ([objcType containsString:@"NSString"]) return @"string";
        if ([objcType containsString:@"NSNumber"]) return @"number";
        if ([objcType containsString:@"NSArray"]) return @"Array";
        if ([objcType containsString:@"NSDictionary"]) return @"Object";
        return @"any";
    }

    if ([objcType isEqualToString:@"i"] || [objcType isEqualToString:@"l"] ||
        [objcType isEqualToString:@"q"]) return @"number";
    if ([objcType isEqualToString:@"f"] || [objcType isEqualToString:@"d"]) return @"number";
    if ([objcType isEqualToString:@"B"] || [objcType isEqualToString:@"c"]) return @"boolean";

    return @"any";
}

@end
