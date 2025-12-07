//
//  PKScriptingDefinitionGenerator.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PKIntrospectionResult;

/// Output format for scripting definitions
typedef NS_ENUM(NSInteger, PKScriptingDefinitionFormat) {
    PKScriptingDefinitionFormatAppleScript,
    PKScriptingDefinitionFormatJavaScript,
    PKScriptingDefinitionFormatSDEF  // Scripting Definition (XML)
};

/// Options for scripting definition generation
typedef NS_OPTIONS(NSUInteger, PKScriptingDefinitionOptions) {
    PKScriptingDefinitionOptionsNone           = 0,
    PKScriptingDefinitionOptionsIncludePrivate = 1 << 0,
    PKScriptingDefinitionOptionsVerbose        = 1 << 1,
    PKScriptingDefinitionOptionsIncludeTypes   = 1 << 2
};

/// Generator for AppleScript and JavaScript scripting definitions
@interface PKScriptingDefinitionGenerator : NSObject

/// Generate scripting definition from introspection result
/// @param result Introspection result
/// @param format Output format
/// @param options Generation options
/// @return Generated scripting definition string
+ (NSString *)generateDefinitionFromIntrospectionResult:(PKIntrospectionResult *)result
                                                 format:(PKScriptingDefinitionFormat)format
                                                options:(PKScriptingDefinitionOptions)options;

/// Generate SDEF (Scripting Definition) XML
/// @param results Array of introspection results
/// @param suiteName Name for the scripting suite
/// @param options Generation options
/// @return SDEF XML string
+ (NSString *)generateSDEFFromIntrospectionResults:(NSArray<PKIntrospectionResult *> *)results
                                         suiteName:(NSString *)suiteName
                                           options:(PKScriptingDefinitionOptions)options;

/// Generate AppleScript dictionary format
/// @param result Introspection result
/// @param options Generation options
/// @return AppleScript-formatted definition
+ (NSString *)generateAppleScriptDefinition:(PKIntrospectionResult *)result
                                    options:(PKScriptingDefinitionOptions)options;

/// Generate JavaScript for Automation (JXA) definitions
/// @param result Introspection result
/// @param options Generation options
/// @return JXA-formatted definition
+ (NSString *)generateJavaScriptDefinition:(PKIntrospectionResult *)result
                                   options:(PKScriptingDefinitionOptions)options;

/// Export definition to file
/// @param definition Definition string
/// @param url Destination file URL
/// @param error Error pointer
/// @return YES if successful
+ (BOOL)exportDefinition:(NSString *)definition
                   toURL:(NSURL *)url
                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
