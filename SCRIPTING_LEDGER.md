# Scripting Ledger - LLVM-based AST, Parser, and Registry

## Overview

The Scripting Ledger is a powerful LLVM-based system for parsing, validating, managing, and generating scripting definitions for PlugInKit plugins. It provides a complete Abstract Syntax Tree (AST) representation, robust parser infrastructure, and a centralized registry for scripting definitions.

## Architecture

The system consists of four main components:

### 1. AST (Abstract Syntax Tree)
- **Location**: `Sources/PlugInKit/ScriptingBridge/PKScriptingAST.{h,cpp}`
- **Purpose**: Structured representation of scripting definitions
- **Key Classes**:
  - `SDEFDocument`: Root node representing an entire scripting definition
  - `Suite`: Collection of commands, classes, and enumerations
  - `Command`: Scriptable command with parameters and return type
  - `Class`: Scriptable class with properties
  - `Enumeration`: Enumeration type with values
  - `TypeRef`: Type reference (builtin or custom)
  - `Parameter`, `Property`: Command/class members
  - `ASTContext`: Memory management and ownership
  - `ASTVisitor`: Visitor pattern for AST traversal

### 2. Parser
- **Location**: `Sources/PlugInKit/ScriptingBridge/PKScriptingParser.{h,cpp}`
- **Purpose**: Parse scripting definitions into AST
- **Features**:
  - LLVM-inspired lexer and parser design
  - Full SDEF (Scripting Definition) XML support
  - Comprehensive error reporting with source locations
  - Token-based lexical analysis
  - Recursive descent parsing
- **Key Classes**:
  - `Lexer`: Tokenizes input source
  - `SDEFParser`: Parses SDEF XML into AST
  - `DiagnosticEngine`: Collects and reports errors/warnings
  - `ParserFactory`: Factory for creating parsers

### 3. Ledger (Registry)
- **Location**: `Sources/PlugInKit/ScriptingBridge/PKScriptingLedger.{h,cpp}`
- **Purpose**: Centralized registry and validation system
- **Features**:
  - Register and manage multiple scripting definitions
  - Validation with detailed error reporting
  - Query interface for finding commands, classes, types
  - Code generation (SDEF, AppleScript, JavaScript)
  - Export/import capabilities
- **Key Classes**:
  - `ScriptingLedger`: Main registry
  - `LedgerEntry`: Individual definition entry
  - `Validator`: AST validation with semantic checks
  - `CodeGenerator`: Generate code from AST
  - `LedgerQuery`: Advanced query interface

### 4. Objective-C Wrapper
- **Location**: `Sources/PlugInKit/ScriptingBridge/PKScriptingLedgerWrapper.{h,mm}`
- **Purpose**: Objective-C/Swift interface to C++ implementation
- **Key Classes**:
  - `PKScriptingLedger`: Main Objective-C interface
  - `PKLedgerEntry`: Ledger entry wrapper
  - `PKValidationResult`: Validation results
  - `PKValidationIssue`: Individual validation issue
  - `PKDiagnostic`: Parser diagnostic message

## Usage

### Basic Usage

```objective-c
#import <PlugInKit/PlugInKit.h>

// Create or use shared ledger
PKScriptingLedger *ledger = [PKScriptingLedger sharedLedger];

// Register a scripting definition
NSString *sdefSource = @"<?xml version=\"1.0\"?>\n"
    @"<dictionary title=\"My Plugin\">\n"
    @"  <suite name=\"Main Suite\" code=\"MSte\">\n"
    @"    <command name=\"do something\" code=\"MStedsth\">\n"
    @"      <parameter name=\"input\" code=\"inpt\" type=\"text\"/>\n"
    @"      <result type=\"text\"/>\n"
    @"    </command>\n"
    @"  </suite>\n"
    @"</dictionary>";

NSError *error = nil;
BOOL success = [ledger registerDefinition:@"com.example.plugin"
                                   source:sdefSource
                                   format:PKScriptingFormatSDEF
                                 filename:@"plugin.sdef"
                                    error:&error];

if (!success) {
    NSLog(@"Failed: %@", error);
    for (PKDiagnostic *diag in [ledger diagnostics]) {
        NSLog(@"%@", diag);
    }
}
```

### Validation

```objective-c
// Validate a specific definition
PKValidationResult *result = [ledger validateDefinition:@"com.example.plugin"];

if (result.isValid) {
    NSLog(@"Valid!");
} else {
    NSLog(@"Found %lu errors, %lu warnings",
          result.errorCount, result.warningCount);
    for (PKValidationIssue *issue in result.issues) {
        NSLog(@"%@", issue);
    }
}

// Validate all definitions
BOOL allValid = [ledger validateAll];
```

### Queries

```objective-c
// Check if definition exists
if ([ledger hasDefinition:@"com.example.plugin"]) {
    // ...
}

// Get ledger entry
PKLedgerEntry *entry = [ledger entryForIdentifier:@"com.example.plugin"];
NSLog(@"Format: %@, Valid: %@", entry.format, entry.isValid ? @"YES" : @"NO");

// Find a command
NSDictionary *cmdInfo = [ledger findCommand:@"do something"
                               inDefinition:@"com.example.plugin"];
NSLog(@"Command: %@", cmdInfo[@"name"]);
NSLog(@"Return type: %@", cmdInfo[@"returnType"]);
for (NSDictionary *param in cmdInfo[@"parameters"]) {
    NSLog(@"  Parameter: %@ (%@)", param[@"name"], param[@"type"]);
}

// Find a class
NSDictionary *clsInfo = [ledger findClass:@"configuration"
                             inDefinition:@"com.example.plugin"];

// Pattern matching
NSArray *commands = [ledger findCommandsMatchingPattern:@"process.*"];

// Get all used types
NSSet<NSString *> *types = [ledger allUsedTypes];
```

### Code Generation

```objective-c
// Generate SDEF XML
NSString *sdef = [ledger generateSDEF:@"com.example.plugin"];

// Generate AppleScript
NSString *applescript = [ledger generateAppleScript:@"com.example.plugin"];

// Generate JavaScript
NSString *javascript = [ledger generateJavaScript:@"com.example.plugin"];

// Export to file
NSURL *url = [NSURL fileURLWithPath:@"/path/to/output.sdef"];
BOOL success = [ledger exportDefinition:@"com.example.plugin"
                                  toURL:url
                                 format:PKScriptingFormatSDEF
                                  error:&error];
```

### Statistics

```objective-c
NSLog(@"Total definitions: %lu", ledger.entryCount);
NSLog(@"Total commands: %lu", ledger.totalCommandCount);
NSLog(@"Total classes: %lu", ledger.totalClassCount);

NSArray<NSString *> *ids = [ledger allIdentifiers];
NSArray<PKLedgerEntry *> *entries = [ledger allEntries];
```

### Loading from File

```objective-c
NSURL *url = [NSURL fileURLWithPath:@"/path/to/plugin.sdef"];
BOOL success = [ledger registerDefinitionFromFile:@"com.example.plugin"
                                              url:url
                                           format:PKScriptingFormatSDEF
                                            error:&error];
```

## Integration with Existing Code

The Scripting Ledger complements the existing `PKScriptingDefinitionGenerator`:

```objective-c
// Traditional approach (still supported)
PKIntrospectionResult *introspection = /* ... */;
NSString *sdef = [PKScriptingDefinitionGenerator
    generateDefinitionFromIntrospectionResult:introspection
                                       format:PKScriptingDefinitionFormatSDEF
                                      options:PKScriptingDefinitionOptionsNone];

// New approach - parse and validate
PKScriptingLedger *ledger = [PKScriptingLedger sharedLedger];
[ledger registerDefinition:@"com.example.plugin"
                    source:sdef
                    format:PKScriptingFormatSDEF
                  filename:@"generated.sdef"
                     error:nil];

// Validate the generated definition
PKValidationResult *validation = [ledger validateDefinition:@"com.example.plugin"];

// Query the parsed structure
NSDictionary *cmdInfo = [ledger findCommand:@"some command"
                               inDefinition:@"com.example.plugin"];
```

## Validation Rules

The validator checks for:

1. **Syntax Errors**: Malformed XML, missing required attributes
2. **Semantic Errors**:
   - Empty or invalid identifiers
   - Duplicate declarations
   - Missing or invalid four-character codes
   - Parameters/properties without types
   - References to undeclared types
3. **Warnings**:
   - Four-character codes not exactly 4 characters
   - Enumerations with no values
   - Identifiers with special characters
   - Used but undeclared custom types

## AST Visitor Pattern

For advanced AST traversal:

```cpp
// C++ only - for advanced usage
class MyVisitor : public PlugInKit::Scripting::ASTVisitor {
public:
    void visitCommand(Command* cmd) override {
        std::cout << "Command: " << cmd->getName() << std::endl;
    }

    void visitClass(Class* cls) override {
        std::cout << "Class: " << cls->getName() << std::endl;
    }

    // Override other visitor methods as needed
};

// Use visitor
MyVisitor visitor;
document->accept(visitor);
```

## Type System

The AST supports the following builtin types:

- `void`: No return value
- `boolean`: Boolean value
- `integer`: Integer number
- `real`: Floating-point number
- `text`: String/text
- `date`: Date/time
- `data`: Binary data
- `any`: Any type
- `object`: Generic object
- `list`: List/array (can have element type)
- `record`: Record/dictionary

Custom types are supported and validated against declared classes and enumerations.

## Performance Considerations

- **Memory Management**: AST nodes are managed by `ASTContext`, ensuring efficient memory usage and proper cleanup
- **Parsing**: The lexer and parser are designed for performance, using single-pass tokenization
- **Validation**: Validation is performed in multiple passes for efficiency
- **Code Generation**: Code generation uses string streaming for minimal allocations

## Thread Safety

- `PKScriptingLedger` instances are not thread-safe by default
- Use `[PKScriptingLedger sharedLedger]` for a singleton instance
- For concurrent access, wrap calls in appropriate synchronization primitives
- Each ledger entry has its own `ASTContext`, isolated from others

## Error Handling

```objective-c
NSError *error = nil;
if (![ledger registerDefinition:id source:src format:fmt filename:file error:&error]) {
    // Check error
    NSLog(@"Error: %@", error.localizedDescription);

    // Get detailed diagnostics
    for (PKDiagnostic *diag in [ledger diagnostics]) {
        NSLog(@"%@:%lu:%lu: %@: %@",
              diag.filename, diag.line, diag.column,
              diag.isError ? @"error" : @"warning",
              diag.message);
    }

    // Clear diagnostics for next operation
    [ledger clearDiagnostics];
}
```

## Future Extensions

The architecture supports future enhancements:

- **AppleScript Parser**: Parse AppleScript `.sdef` dictionaries
- **JavaScript Parser**: Parse JXA type definitions
- **Code Generation**: Generate Objective-C/Swift wrapper code from AST
- **Schema Validation**: Validate against SDEF DTD
- **Merge Operations**: Combine multiple definitions
- **Diff Operations**: Compare definitions for changes
- **Optimization**: Optimize and transform AST
- **Static Analysis**: Analyze definitions for best practices

## Example: Complete Workflow

```objective-c
// 1. Create ledger
PKScriptingLedger *ledger = [[PKScriptingLedger alloc] init];

// 2. Load SDEF from plugin introspection
PKIntrospectionResult *introspection = /* introspect plugin */;
NSString *sdef = [PKScriptingDefinitionGenerator
    generateSDEFFromIntrospectionResults:@[introspection]
                               suiteName:@"Plugin Suite"
                                 options:PKScriptingDefinitionOptionsNone];

// 3. Register in ledger
[ledger registerDefinition:@"com.example.plugin"
                    source:sdef
                    format:PKScriptingFormatSDEF
                  filename:@"plugin.sdef"
                     error:nil];

// 4. Validate
PKValidationResult *validation = [ledger validateDefinition:@"com.example.plugin"];
if (!validation.isValid) {
    for (PKValidationIssue *issue in validation.issues) {
        NSLog(@"%@", issue);
    }
}

// 5. Query
NSSet<NSString *> *types = [ledger allUsedTypes];
NSArray *commands = [ledger findCommandsMatchingPattern:@".*"];

// 6. Generate AppleScript
NSString *applescript = [ledger generateAppleScript:@"com.example.plugin"];

// 7. Export
NSURL *exportURL = [NSURL fileURLWithPath:@"/tmp/plugin.sdef"];
[ledger exportDefinition:@"com.example.plugin"
                   toURL:exportURL
                  format:PKScriptingFormatSDEF
                   error:nil];
```

## See Also

- `PKScriptingDefinitionGenerator`: Generate scripting definitions from introspection
- `PKIntrospector`: Runtime introspection of plugin methods
- `PKConnection`: Plugin connection for introspection
- Example: `Examples/ScriptingLedgerExample/`
