//
//  PKScriptingLedger.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//
//  Ledger system for managing scripting definitions

#ifndef PKScriptingLedger_h
#define PKScriptingLedger_h

#include "PKScriptingAST.h"
#include "PKScriptingParser.h"
#include <string>
#include <map>
#include <vector>
#include <memory>
#include <set>

namespace PlugInKit {
namespace Scripting {

// Validation result
struct ValidationIssue {
    enum class Severity {
        Warning,
        Error
    };

    Severity severity;
    std::string message;
    SourceLocation location;
    std::string context;

    ValidationIssue(Severity sev, const std::string& msg,
                   const SourceLocation& loc = SourceLocation(),
                   const std::string& ctx = "")
        : severity(sev), message(msg), location(loc), context(ctx) {}

    std::string toString() const;
};

// Validation result
class ValidationResult {
private:
    std::vector<ValidationIssue> issues;
    bool valid;

public:
    ValidationResult() : valid(true) {}

    void addIssue(const ValidationIssue& issue) {
        issues.push_back(issue);
        if (issue.severity == ValidationIssue::Severity::Error) {
            valid = false;
        }
    }

    void addError(const std::string& msg, const SourceLocation& loc = SourceLocation()) {
        addIssue(ValidationIssue(ValidationIssue::Severity::Error, msg, loc));
    }

    void addWarning(const std::string& msg, const SourceLocation& loc = SourceLocation()) {
        addIssue(ValidationIssue(ValidationIssue::Severity::Warning, msg, loc));
    }

    bool isValid() const { return valid; }
    const std::vector<ValidationIssue>& getIssues() const { return issues; }

    size_t getErrorCount() const {
        size_t count = 0;
        for (const auto& issue : issues) {
            if (issue.severity == ValidationIssue::Severity::Error) {
                count++;
            }
        }
        return count;
    }

    size_t getWarningCount() const {
        return issues.size() - getErrorCount();
    }
};

// Validator for scripting definitions
class Validator : public ASTVisitor {
private:
    ValidationResult result;
    std::set<std::string> declaredTypes;
    std::set<std::string> usedTypes;
    std::map<std::string, NamedDecl*> namedDeclarations;

    void checkDuplicateName(const std::string& name, const SourceLocation& loc);
    void checkTypeExists(const std::string& typeName, const SourceLocation& loc);
    void checkFourCharCode(const std::string& code, const SourceLocation& loc);
    void checkIdentifier(const std::string& name, const SourceLocation& loc);

public:
    Validator() = default;

    ValidationResult validate(SDEFDocument* doc);

    // Visitor methods
    void visitSDEFDocument(SDEFDocument* doc) override;
    void visitSuite(Suite* suite) override;
    void visitCommand(Command* cmd) override;
    void visitClass(Class* cls) override;
    void visitEnumeration(Enumeration* enm) override;
    void visitEnumerationValue(EnumerationValue* val) override;
    void visitParameter(Parameter* param) override;
    void visitProperty(Property* prop) override;
    void visitTypeRef(TypeRef* type) override;

private:
    void checkUndeclaredTypes();
};

// Ledger entry for a scripting definition
class LedgerEntry {
private:
    std::string identifier;
    std::shared_ptr<SDEFDocument> document;
    ASTContext* context;
    ValidationResult validationResult;
    std::string sourceFile;
    std::string format; // "sdef", "applescript", "javascript"

public:
    LedgerEntry(const std::string& id,
               std::shared_ptr<SDEFDocument> doc,
               ASTContext* ctx,
               const std::string& source,
               const std::string& fmt)
        : identifier(id), document(doc), context(ctx),
          sourceFile(source), format(fmt) {}

    const std::string& getIdentifier() const { return identifier; }
    SDEFDocument* getDocument() const { return document.get(); }
    ASTContext* getContext() const { return context; }
    const ValidationResult& getValidationResult() const { return validationResult; }
    void setValidationResult(const ValidationResult& result) { validationResult = result; }
    const std::string& getSourceFile() const { return sourceFile; }
    const std::string& getFormat() const { return format; }

    bool isValid() const { return validationResult.isValid(); }
};

// The Scripting Ledger - registry and management system
class ScriptingLedger {
private:
    std::map<std::string, std::unique_ptr<LedgerEntry>> entries;
    std::map<std::string, std::unique_ptr<ASTContext>> contexts;
    DiagnosticEngine diagnostics;

public:
    ScriptingLedger() = default;

    // Non-copyable
    ScriptingLedger(const ScriptingLedger&) = delete;
    ScriptingLedger& operator=(const ScriptingLedger&) = delete;

    // Register a scripting definition
    bool registerDefinition(const std::string& identifier,
                          const std::string& source,
                          ParserFactory::Format format,
                          const std::string& filename = "");

    // Remove a definition
    bool removeDefinition(const std::string& identifier);

    // Lookup
    LedgerEntry* getEntry(const std::string& identifier) const;
    SDEFDocument* getDocument(const std::string& identifier) const;

    // Query
    bool hasDefinition(const std::string& identifier) const;
    std::vector<std::string> getAllIdentifiers() const;
    std::vector<LedgerEntry*> getAllEntries() const;

    // Validation
    ValidationResult validateDefinition(const std::string& identifier);
    bool validateAll();

    // Find elements
    Command* findCommand(const std::string& identifier, const std::string& commandName) const;
    Class* findClass(const std::string& identifier, const std::string& className) const;
    Suite* findSuite(const std::string& identifier, const std::string& suiteName) const;

    // Code generation
    std::string generateSDEF(const std::string& identifier) const;
    std::string generateAppleScript(const std::string& identifier) const;
    std::string generateJavaScript(const std::string& identifier) const;

    // Diagnostics
    const DiagnosticEngine& getDiagnostics() const { return diagnostics; }
    void clearDiagnostics() { diagnostics.clear(); }

    // Statistics
    size_t getEntryCount() const { return entries.size(); }
    size_t getTotalCommandCount() const;
    size_t getTotalClassCount() const;

    // Merge definitions
    bool mergeDefinitions(const std::string& targetId, const std::string& sourceId);

    // Export/Import
    bool exportToFile(const std::string& identifier, const std::string& filename,
                     ParserFactory::Format format) const;
};

// Code generator from AST
class CodeGenerator : public ASTVisitor {
public:
    enum class OutputFormat {
        SDEF,
        AppleScript,
        JavaScript
    };

private:
    OutputFormat format;
    std::ostringstream output;
    int indentLevel;

    void indent();
    void emitLine(const std::string& line);
    void emitIndented(const std::string& line);

public:
    CodeGenerator(OutputFormat fmt)
        : format(fmt), indentLevel(0) {}

    std::string generate(SDEFDocument* doc);

    // Visitor methods
    void visitSDEFDocument(SDEFDocument* doc) override;
    void visitSuite(Suite* suite) override;
    void visitCommand(Command* cmd) override;
    void visitClass(Class* cls) override;
    void visitEnumeration(Enumeration* enm) override;
    void visitEnumerationValue(EnumerationValue* val) override;
    void visitParameter(Parameter* param) override;
    void visitProperty(Property* prop) override;
    void visitTypeRef(TypeRef* type) override;
};

// Query interface for advanced lookups
class LedgerQuery {
private:
    const ScriptingLedger& ledger;

public:
    explicit LedgerQuery(const ScriptingLedger& l) : ledger(l) {}

    // Find all commands matching a pattern
    std::vector<Command*> findCommandsMatching(const std::string& pattern) const;

    // Find all classes inheriting from a base class
    std::vector<Class*> findClassesInheritingFrom(const std::string& baseClass) const;

    // Find commands with specific return type
    std::vector<Command*> findCommandsReturningType(const std::string& typeName) const;

    // Find all types used across all definitions
    std::set<std::string> getAllUsedTypes() const;

    // Find duplicate command names across definitions
    std::map<std::string, std::vector<Command*>> findDuplicateCommands() const;
};

} // namespace Scripting
} // namespace PlugInKit

#endif /* PKScriptingLedger_h */
