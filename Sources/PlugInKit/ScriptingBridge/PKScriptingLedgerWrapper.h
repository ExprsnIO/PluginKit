//
//  PKScriptingLedgerWrapper.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//
//  Objective-C wrapper for LLVM-based scripting ledger

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Format for scripting definitions
typedef NS_ENUM(NSInteger, PKScriptingFormat) {
    PKScriptingFormatSDEF,
    PKScriptingFormatAppleScript,
    PKScriptingFormatJavaScript
};

/// Validation issue severity
typedef NS_ENUM(NSInteger, PKValidationSeverity) {
    PKValidationSeverityWarning,
    PKValidationSeverityError
};

/// Validation issue
@interface PKValidationIssue : NSObject

@property (nonatomic, readonly) PKValidationSeverity severity;
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, copy, readonly, nullable) NSString *filename;
@property (nonatomic, readonly) NSUInteger line;
@property (nonatomic, readonly) NSUInteger column;
@property (nonatomic, copy, readonly, nullable) NSString *context;

- (NSString *)description;

@end

/// Validation result
@interface PKValidationResult : NSObject

@property (nonatomic, readonly) BOOL isValid;
@property (nonatomic, copy, readonly) NSArray<PKValidationIssue *> *issues;
@property (nonatomic, readonly) NSUInteger errorCount;
@property (nonatomic, readonly) NSUInteger warningCount;

@end

/// Diagnostic message from parser
@interface PKDiagnostic : NSObject

@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, copy, readonly, nullable) NSString *filename;
@property (nonatomic, readonly) NSUInteger line;
@property (nonatomic, readonly) NSUInteger column;
@property (nonatomic, readonly) BOOL isError;

- (NSString *)description;

@end

/// Ledger entry for a scripting definition
@interface PKLedgerEntry : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *sourceFile;
@property (nonatomic, copy, readonly) NSString *format;
@property (nonatomic, strong, readonly) PKValidationResult *validationResult;
@property (nonatomic, readonly) BOOL isValid;

@end

/// Scripting Ledger - registry and management system for scripting definitions
@interface PKScriptingLedger : NSObject

/// Shared instance
+ (instancetype)sharedLedger;

/// Create a new ledger instance
- (instancetype)init;

// Registration and removal

/// Register a scripting definition from source
/// @param identifier Unique identifier for this definition
/// @param source Source code (SDEF XML, AppleScript, or JavaScript)
/// @param format Format of the source
/// @param filename Optional filename for error reporting
/// @param error Error pointer
/// @return YES if successful
- (BOOL)registerDefinition:(NSString *)identifier
                    source:(NSString *)source
                    format:(PKScriptingFormat)format
                  filename:(nullable NSString *)filename
                     error:(NSError **)error;

/// Register a scripting definition from file
/// @param identifier Unique identifier for this definition
/// @param url File URL
/// @param format Format of the file
/// @param error Error pointer
/// @return YES if successful
- (BOOL)registerDefinitionFromFile:(NSString *)identifier
                               url:(NSURL *)url
                            format:(PKScriptingFormat)format
                             error:(NSError **)error;

/// Remove a definition
/// @param identifier Identifier to remove
/// @return YES if successful
- (BOOL)removeDefinition:(NSString *)identifier;

// Lookup and queries

/// Check if a definition exists
/// @param identifier Identifier to check
/// @return YES if definition exists
- (BOOL)hasDefinition:(NSString *)identifier;

/// Get a ledger entry
/// @param identifier Identifier to lookup
/// @return Ledger entry or nil
- (nullable PKLedgerEntry *)entryForIdentifier:(NSString *)identifier;

/// Get all registered identifiers
/// @return Array of identifiers
- (NSArray<NSString *> *)allIdentifiers;

/// Get all ledger entries
/// @return Array of entries
- (NSArray<PKLedgerEntry *> *)allEntries;

/// Get number of registered definitions
@property (nonatomic, readonly) NSUInteger entryCount;

/// Get total number of commands across all definitions
@property (nonatomic, readonly) NSUInteger totalCommandCount;

/// Get total number of classes across all definitions
@property (nonatomic, readonly) NSUInteger totalClassCount;

// Validation

/// Validate a specific definition
/// @param identifier Identifier to validate
/// @return Validation result
- (PKValidationResult *)validateDefinition:(NSString *)identifier;

/// Validate all definitions
/// @return YES if all definitions are valid
- (BOOL)validateAll;

// Code generation

/// Generate SDEF XML from a definition
/// @param identifier Identifier
/// @return SDEF XML string
- (nullable NSString *)generateSDEF:(NSString *)identifier;

/// Generate AppleScript from a definition
/// @param identifier Identifier
/// @return AppleScript string
- (nullable NSString *)generateAppleScript:(NSString *)identifier;

/// Generate JavaScript from a definition
/// @param identifier Identifier
/// @return JavaScript string
- (nullable NSString *)generateJavaScript:(NSString *)identifier;

// Export

/// Export definition to file
/// @param identifier Identifier
/// @param url Destination file URL
/// @param format Output format
/// @param error Error pointer
/// @return YES if successful
- (BOOL)exportDefinition:(NSString *)identifier
                   toURL:(NSURL *)url
                  format:(PKScriptingFormat)format
                   error:(NSError **)error;

// Diagnostics

/// Get parser diagnostics from last operation
/// @return Array of diagnostics
- (NSArray<PKDiagnostic *> *)diagnostics;

/// Clear diagnostics
- (void)clearDiagnostics;

// Advanced queries

/// Find command by name
/// @param identifier Definition identifier
/// @param commandName Command name
/// @return Command info dictionary or nil
- (nullable NSDictionary<NSString *, id> *)findCommand:(NSString *)commandName
                                          inDefinition:(NSString *)identifier;

/// Find class by name
/// @param identifier Definition identifier
/// @param className Class name
/// @return Class info dictionary or nil
- (nullable NSDictionary<NSString *, id> *)findClass:(NSString *)className
                                        inDefinition:(NSString *)identifier;

/// Find all commands matching a pattern
/// @param pattern Regex pattern
/// @return Array of command info dictionaries
- (NSArray<NSDictionary<NSString *, id> *> *)findCommandsMatchingPattern:(NSString *)pattern;

/// Find all types used across all definitions
/// @return Set of type names
- (NSSet<NSString *> *)allUsedTypes;

@end

NS_ASSUME_NONNULL_END
