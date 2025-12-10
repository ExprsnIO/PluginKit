//
//  ScriptingLedgerExample.m
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//
//  Example usage of LLVM-based Scripting Ledger

#import <Foundation/Foundation.h>
#import "PKScriptingLedgerWrapper.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== PlugInKit Scripting Ledger Example ===\n");

        // Create a ledger instance
        PKScriptingLedger *ledger = [[PKScriptingLedger alloc] init];

        // Example SDEF XML
        NSString *sampleSDEF = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        @"<!DOCTYPE dictionary SYSTEM \"file://localhost/System/Library/DTDs/sdef.dtd\">\n"
        @"<dictionary title=\"Sample Plugin\">\n"
        @"  <suite name=\"Sample Suite\" code=\"SPLt\" description=\"Sample plugin commands\">\n"
        @"    <command name=\"process data\" code=\"SPLtproc\" description=\"Process data\">\n"
        @"      <parameter name=\"input\" code=\"inpt\" type=\"text\" description=\"Input data\"/>\n"
        @"      <parameter name=\"options\" code=\"opts\" type=\"record\" optional=\"yes\" description=\"Processing options\"/>\n"
        @"      <result type=\"text\" description=\"Processed result\"/>\n"
        @"    </command>\n"
        @"    <command name=\"get status\" code=\"SPLtstat\" description=\"Get plugin status\">\n"
        @"      <result type=\"record\" description=\"Status information\"/>\n"
        @"    </command>\n"
        @"    <class name=\"configuration\" code=\"CFGr\" description=\"Plugin configuration\">\n"
        @"      <property name=\"enabled\" code=\"enbl\" type=\"boolean\" description=\"Whether plugin is enabled\"/>\n"
        @"      <property name=\"timeout\" code=\"tout\" type=\"integer\" description=\"Timeout in seconds\"/>\n"
        @"      <property name=\"name\" code=\"pnam\" type=\"text\" access=\"r\" description=\"Plugin name\"/>\n"
        @"    </class>\n"
        @"  </suite>\n"
        @"</dictionary>";

        // Register the definition
        NSLog(@"Registering SDEF definition...");
        NSError *error = nil;
        BOOL success = [ledger registerDefinition:@"com.example.sampleplugin"
                                           source:sampleSDEF
                                           format:PKScriptingFormatSDEF
                                         filename:@"sample.sdef"
                                            error:&error];

        if (!success) {
            NSLog(@"Failed to register definition: %@", error);
            for (PKDiagnostic *diag in [ledger diagnostics]) {
                NSLog(@"  %@", diag);
            }
            return 1;
        }

        NSLog(@"✓ Successfully registered definition\n");

        // Validate the definition
        NSLog(@"Validating definition...");
        PKValidationResult *validationResult = [ledger validateDefinition:@"com.example.sampleplugin"];

        if (validationResult.isValid) {
            NSLog(@"✓ Definition is valid!");
        } else {
            NSLog(@"✗ Definition has issues:");
            for (PKValidationIssue *issue in validationResult.issues) {
                NSLog(@"  %@", issue);
            }
        }
        NSLog(@"  Errors: %lu, Warnings: %lu\n",
              (unsigned long)validationResult.errorCount,
              (unsigned long)validationResult.warningCount);

        // Query ledger statistics
        NSLog(@"Ledger Statistics:");
        NSLog(@"  Total definitions: %lu", (unsigned long)ledger.entryCount);
        NSLog(@"  Total commands: %lu", (unsigned long)ledger.totalCommandCount);
        NSLog(@"  Total classes: %lu\n", (unsigned long)ledger.totalClassCount);

        // Find a specific command
        NSLog(@"Finding command 'process data'...");
        NSDictionary *cmdInfo = [ledger findCommand:@"process data"
                                       inDefinition:@"com.example.sampleplugin"];

        if (cmdInfo) {
            NSLog(@"✓ Found command:");
            NSLog(@"  Name: %@", cmdInfo[@"name"]);
            NSLog(@"  Code: %@", cmdInfo[@"code"]);
            NSLog(@"  Return Type: %@", cmdInfo[@"returnType"]);
            NSLog(@"  Parameters:");
            for (NSDictionary *param in cmdInfo[@"parameters"]) {
                NSLog(@"    - %@ (%@)%@", param[@"name"], param[@"type"],
                      [param[@"optional"] boolValue] ? @" [optional]" : @"");
            }
        } else {
            NSLog(@"✗ Command not found");
        }
        NSLog(@"");

        // Find a specific class
        NSLog(@"Finding class 'configuration'...");
        NSDictionary *clsInfo = [ledger findClass:@"configuration"
                                     inDefinition:@"com.example.sampleplugin"];

        if (clsInfo) {
            NSLog(@"✓ Found class:");
            NSLog(@"  Name: %@", clsInfo[@"name"]);
            NSLog(@"  Code: %@", clsInfo[@"code"]);
            NSLog(@"  Properties:");
            for (NSDictionary *prop in clsInfo[@"properties"]) {
                NSLog(@"    - %@ (%@)%@", prop[@"name"], prop[@"type"],
                      [prop[@"readOnly"] boolValue] ? @" [read-only]" : @"");
            }
        } else {
            NSLog(@"✗ Class not found");
        }
        NSLog(@"");

        // Generate SDEF output
        NSLog(@"Regenerating SDEF...");
        NSString *generatedSDEF = [ledger generateSDEF:@"com.example.sampleplugin"];
        if (generatedSDEF) {
            NSLog(@"✓ Generated SDEF:\n%@\n", generatedSDEF);
        }

        // Generate AppleScript
        NSLog(@"Generating AppleScript definitions...");
        NSString *appleScript = [ledger generateAppleScript:@"com.example.sampleplugin"];
        if (appleScript) {
            NSLog(@"✓ AppleScript:\n%@\n", appleScript);
        }

        // Generate JavaScript
        NSLog(@"Generating JavaScript definitions...");
        NSString *javaScript = [ledger generateJavaScript:@"com.example.sampleplugin"];
        if (javaScript) {
            NSLog(@"✓ JavaScript:\n%@\n", javaScript);
        }

        // Query all used types
        NSLog(@"All types used in definitions:");
        NSSet<NSString *> *types = [ledger allUsedTypes];
        for (NSString *type in [types.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
            NSLog(@"  - %@", type);
        }
        NSLog(@"");

        // Export to file
        NSLog(@"Exporting SDEF to file...");
        NSURL *exportURL = [NSURL fileURLWithPath:@"/tmp/exported.sdef"];
        success = [ledger exportDefinition:@"com.example.sampleplugin"
                                     toURL:exportURL
                                    format:PKScriptingFormatSDEF
                                     error:&error];

        if (success) {
            NSLog(@"✓ Successfully exported to %@", exportURL.path);
        } else {
            NSLog(@"✗ Export failed: %@", error);
        }
        NSLog(@"");

        // Demonstrate shared ledger
        NSLog(@"Using shared ledger instance...");
        PKScriptingLedger *sharedLedger = [PKScriptingLedger sharedLedger];
        NSLog(@"Shared ledger has %lu definitions", (unsigned long)sharedLedger.entryCount);

        // Register in shared ledger
        [sharedLedger registerDefinition:@"com.example.shared"
                                  source:sampleSDEF
                                  format:PKScriptingFormatSDEF
                                filename:@"shared.sdef"
                                   error:nil];
        NSLog(@"After registration: %lu definitions\n", (unsigned long)sharedLedger.entryCount);

        // List all definitions
        NSLog(@"All registered definitions:");
        for (NSString *identifier in [sharedLedger allIdentifiers]) {
            PKLedgerEntry *entry = [sharedLedger entryForIdentifier:identifier];
            NSLog(@"  - %@ (format: %@, valid: %@)",
                  identifier, entry.format, entry.isValid ? @"YES" : @"NO");
        }
        NSLog(@"");

        // Pattern matching
        NSLog(@"Finding commands matching 'data'...");
        NSArray *matchingCommands = [sharedLedger findCommandsMatchingPattern:@"data"];
        NSLog(@"Found %lu matching commands:", (unsigned long)matchingCommands.count);
        for (NSDictionary *cmd in matchingCommands) {
            NSLog(@"  - %@ in %@ (suite: %@)",
                  cmd[@"name"], cmd[@"definitionIdentifier"], cmd[@"suiteName"]);
        }
        NSLog(@"");

        NSLog(@"=== Example Complete ===");
    }
    return 0;
}
