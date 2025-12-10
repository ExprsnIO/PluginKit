//
//  PKScriptingLedgerWrapper.mm
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//
//  Objective-C++ wrapper implementation

#import "PKScriptingLedgerWrapper.h"
#include "PKScriptingLedger.h"
#include <memory>
#include <string>

using namespace PlugInKit::Scripting;

// Error domain
static NSString * const PKScriptingLedgerErrorDomain = @"com.pluginkit.scripting.ledger";

// Convert C++ string to NSString
static NSString *toNSString(const std::string& str) {
    return [NSString stringWithUTF8String:str.c_str()];
}

// Convert NSString to C++ string
static std::string toCppString(NSString *str) {
    return str ? std::string([str UTF8String]) : std::string();
}

#pragma mark - PKValidationIssue

@interface PKValidationIssue ()
@property (nonatomic, readwrite) PKValidationSeverity severity;
@property (nonatomic, copy, readwrite) NSString *message;
@property (nonatomic, copy, readwrite) NSString *filename;
@property (nonatomic, readwrite) NSUInteger line;
@property (nonatomic, readwrite) NSUInteger column;
@property (nonatomic, copy, readwrite) NSString *context;
@end

@implementation PKValidationIssue

- (NSString *)description {
    NSMutableString *desc = [NSMutableString string];

    if (self.filename && self.line > 0) {
        [desc appendFormat:@"%@:%lu:%lu: ", self.filename, (unsigned long)self.line, (unsigned long)self.column];
    }

    [desc appendString:self.severity == PKValidationSeverityError ? @"error: " : @"warning: "];
    [desc appendString:self.message];

    if (self.context) {
        [desc appendFormat:@" [%@]", self.context];
    }

    return desc;
}

@end

#pragma mark - PKValidationResult

@interface PKValidationResult ()
@property (nonatomic, readwrite) BOOL isValid;
@property (nonatomic, copy, readwrite) NSArray<PKValidationIssue *> *issues;
@end

@implementation PKValidationResult

- (NSUInteger)errorCount {
    NSUInteger count = 0;
    for (PKValidationIssue *issue in self.issues) {
        if (issue.severity == PKValidationSeverityError) {
            count++;
        }
    }
    return count;
}

- (NSUInteger)warningCount {
    return self.issues.count - self.errorCount;
}

@end

#pragma mark - PKDiagnostic

@interface PKDiagnostic ()
@property (nonatomic, copy, readwrite) NSString *message;
@property (nonatomic, copy, readwrite) NSString *filename;
@property (nonatomic, readwrite) NSUInteger line;
@property (nonatomic, readwrite) NSUInteger column;
@property (nonatomic, readwrite) BOOL isError;
@end

@implementation PKDiagnostic

- (NSString *)description {
    NSMutableString *desc = [NSMutableString string];

    if (self.filename && self.line > 0) {
        [desc appendFormat:@"%@:%lu:%lu: ", self.filename, (unsigned long)self.line, (unsigned long)self.column];
    }

    [desc appendString:self.isError ? @"error: " : @"warning: "];
    [desc appendString:self.message];

    return desc;
}

@end

#pragma mark - PKLedgerEntry

@interface PKLedgerEntry ()
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *sourceFile;
@property (nonatomic, copy, readwrite) NSString *format;
@property (nonatomic, strong, readwrite) PKValidationResult *validationResult;
@end

@implementation PKLedgerEntry

- (BOOL)isValid {
    return self.validationResult.isValid;
}

@end

#pragma mark - PKScriptingLedger

@interface PKScriptingLedger () {
    std::unique_ptr<ScriptingLedger> _ledger;
}
@end

@implementation PKScriptingLedger

+ (instancetype)sharedLedger {
    static PKScriptingLedger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _ledger = std::make_unique<ScriptingLedger>();
    }
    return self;
}

- (BOOL)registerDefinition:(NSString *)identifier
                    source:(NSString *)source
                    format:(PKScriptingFormat)format
                  filename:(NSString *)filename
                     error:(NSError **)error {
    ParserFactory::Format cppFormat;
    switch (format) {
        case PKScriptingFormatSDEF:
            cppFormat = ParserFactory::Format::SDEF;
            break;
        case PKScriptingFormatAppleScript:
            cppFormat = ParserFactory::Format::AppleScript;
            break;
        case PKScriptingFormatJavaScript:
            cppFormat = ParserFactory::Format::JavaScript;
            break;
    }

    std::string cppId = toCppString(identifier);
    std::string cppSource = toCppString(source);
    std::string cppFilename = toCppString(filename ?: @"<input>");

    BOOL success = _ledger->registerDefinition(cppId, cppSource, cppFormat, cppFilename);

    if (!success && error) {
        NSMutableString *errorMsg = [NSMutableString stringWithString:@"Failed to parse scripting definition"];

        const auto& diagnostics = _ledger->getDiagnostics();
        if (diagnostics.hasErrors()) {
            [errorMsg appendString:@":\n"];
            for (const auto& diag : diagnostics.getDiagnostics()) {
                [errorMsg appendFormat:@"  %s\n", diag.toString().c_str()];
            }
        }

        *error = [NSError errorWithDomain:PKScriptingLedgerErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
    }

    return success;
}

- (BOOL)registerDefinitionFromFile:(NSString *)identifier
                               url:(NSURL *)url
                            format:(PKScriptingFormat)format
                             error:(NSError **)error {
    NSString *source = [NSString stringWithContentsOfURL:url
                                                encoding:NSUTF8StringEncoding
                                                   error:error];
    if (!source) {
        return NO;
    }

    return [self registerDefinition:identifier
                             source:source
                             format:format
                           filename:url.path
                              error:error];
}

- (BOOL)removeDefinition:(NSString *)identifier {
    return _ledger->removeDefinition(toCppString(identifier));
}

- (BOOL)hasDefinition:(NSString *)identifier {
    return _ledger->hasDefinition(toCppString(identifier));
}

- (PKLedgerEntry *)entryForIdentifier:(NSString *)identifier {
    LedgerEntry *cppEntry = _ledger->getEntry(toCppString(identifier));
    if (!cppEntry) {
        return nil;
    }

    PKLedgerEntry *entry = [[PKLedgerEntry alloc] init];
    entry.identifier = toNSString(cppEntry->getIdentifier());
    entry.sourceFile = toNSString(cppEntry->getSourceFile());
    entry.format = toNSString(cppEntry->getFormat());

    // Convert validation result
    PKValidationResult *validationResult = [[PKValidationResult alloc] init];
    const auto& cppResult = cppEntry->getValidationResult();
    validationResult.isValid = cppResult.isValid();

    NSMutableArray<PKValidationIssue *> *issues = [NSMutableArray array];
    for (const auto& cppIssue : cppResult.getIssues()) {
        PKValidationIssue *issue = [[PKValidationIssue alloc] init];
        issue.severity = cppIssue.severity == ValidationIssue::Severity::Error ?
                         PKValidationSeverityError : PKValidationSeverityWarning;
        issue.message = toNSString(cppIssue.message);
        issue.filename = toNSString(cppIssue.location.filename);
        issue.line = cppIssue.location.line;
        issue.column = cppIssue.location.column;
        issue.context = toNSString(cppIssue.context);
        [issues addObject:issue];
    }
    validationResult.issues = issues;

    entry.validationResult = validationResult;

    return entry;
}

- (NSArray<NSString *> *)allIdentifiers {
    std::vector<std::string> cppIds = _ledger->getAllIdentifiers();
    NSMutableArray<NSString *> *ids = [NSMutableArray arrayWithCapacity:cppIds.size()];
    for (const auto& id : cppIds) {
        [ids addObject:toNSString(id)];
    }
    return ids;
}

- (NSArray<PKLedgerEntry *> *)allEntries {
    NSMutableArray<PKLedgerEntry *> *entries = [NSMutableArray array];
    for (NSString *identifier in [self allIdentifiers]) {
        PKLedgerEntry *entry = [self entryForIdentifier:identifier];
        if (entry) {
            [entries addObject:entry];
        }
    }
    return entries;
}

- (NSUInteger)entryCount {
    return _ledger->getEntryCount();
}

- (NSUInteger)totalCommandCount {
    return _ledger->getTotalCommandCount();
}

- (NSUInteger)totalClassCount {
    return _ledger->getTotalClassCount();
}

- (PKValidationResult *)validateDefinition:(NSString *)identifier {
    ValidationResult cppResult = _ledger->validateDefinition(toCppString(identifier));

    PKValidationResult *result = [[PKValidationResult alloc] init];
    result.isValid = cppResult.isValid();

    NSMutableArray<PKValidationIssue *> *issues = [NSMutableArray array];
    for (const auto& cppIssue : cppResult.getIssues()) {
        PKValidationIssue *issue = [[PKValidationIssue alloc] init];
        issue.severity = cppIssue.severity == ValidationIssue::Severity::Error ?
                         PKValidationSeverityError : PKValidationSeverityWarning;
        issue.message = toNSString(cppIssue.message);
        issue.filename = toNSString(cppIssue.location.filename);
        issue.line = cppIssue.location.line;
        issue.column = cppIssue.location.column;
        issue.context = toNSString(cppIssue.context);
        [issues addObject:issue];
    }
    result.issues = issues;

    return result;
}

- (BOOL)validateAll {
    return _ledger->validateAll();
}

- (NSString *)generateSDEF:(NSString *)identifier {
    std::string result = _ledger->generateSDEF(toCppString(identifier));
    return result.empty() ? nil : toNSString(result);
}

- (NSString *)generateAppleScript:(NSString *)identifier {
    std::string result = _ledger->generateAppleScript(toCppString(identifier));
    return result.empty() ? nil : toNSString(result);
}

- (NSString *)generateJavaScript:(NSString *)identifier {
    std::string result = _ledger->generateJavaScript(toCppString(identifier));
    return result.empty() ? nil : toNSString(result);
}

- (BOOL)exportDefinition:(NSString *)identifier
                   toURL:(NSURL *)url
                  format:(PKScriptingFormat)format
                   error:(NSError **)error {
    NSString *output = nil;

    switch (format) {
        case PKScriptingFormatSDEF:
            output = [self generateSDEF:identifier];
            break;
        case PKScriptingFormatAppleScript:
            output = [self generateAppleScript:identifier];
            break;
        case PKScriptingFormatJavaScript:
            output = [self generateJavaScript:identifier];
            break;
    }

    if (!output) {
        if (error) {
            *error = [NSError errorWithDomain:PKScriptingLedgerErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate output"}];
        }
        return NO;
    }

    return [output writeToURL:url
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:error];
}

- (NSArray<PKDiagnostic *> *)diagnostics {
    const auto& cppDiags = _ledger->getDiagnostics();
    NSMutableArray<PKDiagnostic *> *diags = [NSMutableArray array];

    for (const auto& cppDiag : cppDiags.getDiagnostics()) {
        PKDiagnostic *diag = [[PKDiagnostic alloc] init];
        diag.message = toNSString(cppDiag.message);
        diag.filename = toNSString(cppDiag.location.filename);
        diag.line = cppDiag.location.line;
        diag.column = cppDiag.location.column;
        diag.isError = (cppDiag.severity == Diagnostic::Severity::Error);
        [diags addObject:diag];
    }

    return diags;
}

- (void)clearDiagnostics {
    _ledger->clearDiagnostics();
}

- (NSDictionary<NSString *, id> *)findCommand:(NSString *)commandName
                                 inDefinition:(NSString *)identifier {
    Command *cmd = _ledger->findCommand(toCppString(identifier), toCppString(commandName));
    if (!cmd) {
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"name"] = toNSString(cmd->getName());
    info[@"code"] = toNSString(cmd->getCode());
    info[@"documentation"] = toNSString(cmd->getDocumentation());

    if (cmd->getReturnType()) {
        info[@"returnType"] = toNSString(cmd->getReturnType()->toString());
    }

    NSMutableArray *params = [NSMutableArray array];
    for (const auto& param : cmd->getParameters()) {
        NSMutableDictionary *paramInfo = [NSMutableDictionary dictionary];
        paramInfo[@"name"] = toNSString(param->getName());
        if (param->getType()) {
            paramInfo[@"type"] = toNSString(param->getType()->toString());
        }
        paramInfo[@"optional"] = @(param->getIsOptional());
        [params addObject:paramInfo];
    }
    info[@"parameters"] = params;

    return info;
}

- (NSDictionary<NSString *, id> *)findClass:(NSString *)className
                               inDefinition:(NSString *)identifier {
    Class *cls = _ledger->findClass(toCppString(identifier), toCppString(className));
    if (!cls) {
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"name"] = toNSString(cls->getName());
    info[@"code"] = toNSString(cls->getCode());
    info[@"documentation"] = toNSString(cls->getDocumentation());

    if (!cls->getInheritsFrom().empty()) {
        info[@"inheritsFrom"] = toNSString(cls->getInheritsFrom());
    }

    NSMutableArray *props = [NSMutableArray array];
    for (const auto& prop : cls->getProperties()) {
        NSMutableDictionary *propInfo = [NSMutableDictionary dictionary];
        propInfo[@"name"] = toNSString(prop->getName());
        if (prop->getType()) {
            propInfo[@"type"] = toNSString(prop->getType()->toString());
        }
        propInfo[@"readOnly"] = @(prop->getIsReadOnly());
        [props addObject:propInfo];
    }
    info[@"properties"] = props;

    return info;
}

- (NSArray<NSDictionary<NSString *, id> *> *)findCommandsMatchingPattern:(NSString *)pattern {
    // Simple implementation - would need regex support for full pattern matching
    NSMutableArray *results = [NSMutableArray array];

    for (NSString *identifier in [self allIdentifiers]) {
        SDEFDocument *doc = _ledger->getDocument(toCppString(identifier));
        if (!doc) continue;

        for (const auto& suite : doc->getSuites()) {
            for (const auto& cmd : suite->getCommands()) {
                NSString *cmdName = toNSString(cmd->getName());
                if ([cmdName rangeOfString:pattern options:NSRegularExpressionSearch].location != NSNotFound) {
                    NSDictionary *info = [self findCommand:cmdName inDefinition:identifier];
                    if (info) {
                        NSMutableDictionary *extendedInfo = [info mutableCopy];
                        extendedInfo[@"definitionIdentifier"] = identifier;
                        extendedInfo[@"suiteName"] = toNSString(suite->getName());
                        [results addObject:extendedInfo];
                    }
                }
            }
        }
    }

    return results;
}

- (NSSet<NSString *> *)allUsedTypes {
    NSMutableSet<NSString *> *types = [NSMutableSet set];

    for (NSString *identifier in [self allIdentifiers]) {
        SDEFDocument *doc = _ledger->getDocument(toCppString(identifier));
        if (!doc) continue;

        for (const auto& suite : doc->getSuites()) {
            // Collect types from commands
            for (const auto& cmd : suite->getCommands()) {
                if (cmd->getReturnType()) {
                    [types addObject:toNSString(cmd->getReturnType()->toString())];
                }
                for (const auto& param : cmd->getParameters()) {
                    if (param->getType()) {
                        [types addObject:toNSString(param->getType()->toString())];
                    }
                }
            }

            // Collect types from classes
            for (const auto& cls : suite->getClasses()) {
                for (const auto& prop : cls->getProperties()) {
                    if (prop->getType()) {
                        [types addObject:toNSString(prop->getType()->toString())];
                    }
                }
            }
        }
    }

    return types;
}

@end
