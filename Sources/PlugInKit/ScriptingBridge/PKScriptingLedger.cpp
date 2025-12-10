//
//  PKScriptingLedger.cpp
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#include "PKScriptingLedger.h"
#include <sstream>
#include <algorithm>
#include <regex>

namespace PlugInKit {
namespace Scripting {

// ValidationIssue implementation
std::string ValidationIssue::toString() const {
    std::ostringstream oss;

    if (location.isValid()) {
        oss << location.filename << ":" << location.line << ":" << location.column << ": ";
    }

    oss << (severity == Severity::Error ? "error: " : "warning: ");
    oss << message;

    if (!context.empty()) {
        oss << " [" << context << "]";
    }

    return oss.str();
}

// Validator implementation
void Validator::checkDuplicateName(const std::string& name, const SourceLocation& loc) {
    if (namedDeclarations.find(name) != namedDeclarations.end()) {
        result.addWarning("Duplicate declaration: " + name, loc);
    }
}

void Validator::checkTypeExists(const std::string& typeName, const SourceLocation& loc) {
    usedTypes.insert(typeName);
}

void Validator::checkFourCharCode(const std::string& code, const SourceLocation& loc) {
    if (code.length() != 4) {
        result.addWarning("Four-character code should be exactly 4 characters: " + code, loc);
    }
}

void Validator::checkIdentifier(const std::string& name, const SourceLocation& loc) {
    if (name.empty()) {
        result.addError("Empty identifier", loc);
        return;
    }

    // Check for valid characters
    for (char c : name) {
        if (!std::isalnum(c) && c != '_' && c != '-') {
            result.addWarning("Identifier contains special character: " + name, loc);
            break;
        }
    }
}

ValidationResult Validator::validate(SDEFDocument* doc) {
    result = ValidationResult();
    declaredTypes.clear();
    usedTypes.clear();
    namedDeclarations.clear();

    // First pass: collect all declared types
    for (const auto& suite : doc->getSuites()) {
        for (const auto& cls : suite->getClasses()) {
            declaredTypes.insert(cls->getName());
        }
        for (const auto& enm : suite->getEnumerations()) {
            declaredTypes.insert(enm->getName());
        }
    }

    // Second pass: validate structure
    doc->accept(*this);

    // Third pass: check for undeclared types
    checkUndeclaredTypes();

    return result;
}

void Validator::checkUndeclaredTypes() {
    for (const auto& typeName : usedTypes) {
        if (declaredTypes.find(typeName) == declaredTypes.end()) {
            // Check if it's a builtin type
            std::vector<std::string> builtins = {
                "boolean", "integer", "real", "text", "date", "data",
                "any", "list", "record", "object"
            };

            if (std::find(builtins.begin(), builtins.end(), typeName) == builtins.end()) {
                result.addWarning("Type '" + typeName + "' is used but not declared");
            }
        }
    }
}

void Validator::visitSDEFDocument(SDEFDocument* doc) {
    if (doc->getName().empty()) {
        result.addWarning("Document has no name");
    }

    for (const auto& suite : doc->getSuites()) {
        suite->accept(*this);
    }
}

void Validator::visitSuite(Suite* suite) {
    checkIdentifier(suite->getName(), suite->getSourceRange().begin);

    if (!suite->getCode().empty()) {
        checkFourCharCode(suite->getCode(), suite->getSourceRange().begin);
    }

    namedDeclarations[suite->getName()] = suite;

    for (const auto& cmd : suite->getCommands()) {
        cmd->accept(*this);
    }

    for (const auto& cls : suite->getClasses()) {
        cls->accept(*this);
    }

    for (const auto& enm : suite->getEnumerations()) {
        enm->accept(*this);
    }
}

void Validator::visitCommand(Command* cmd) {
    checkIdentifier(cmd->getName(), cmd->getSourceRange().begin);
    checkDuplicateName(cmd->getName(), cmd->getSourceRange().begin);

    if (!cmd->getCode().empty()) {
        checkFourCharCode(cmd->getCode(), cmd->getSourceRange().begin);
    }

    namedDeclarations[cmd->getName()] = cmd;

    for (const auto& param : cmd->getParameters()) {
        param->accept(*this);
    }

    if (cmd->getReturnType()) {
        cmd->getReturnType()->accept(*this);
    }
}

void Validator::visitClass(Class* cls) {
    checkIdentifier(cls->getName(), cls->getSourceRange().begin);
    checkDuplicateName(cls->getName(), cls->getSourceRange().begin);

    if (!cls->getCode().empty()) {
        checkFourCharCode(cls->getCode(), cls->getSourceRange().begin);
    }

    namedDeclarations[cls->getName()] = cls;

    if (!cls->getInheritsFrom().empty()) {
        checkTypeExists(cls->getInheritsFrom(), cls->getSourceRange().begin);
    }

    for (const auto& prop : cls->getProperties()) {
        prop->accept(*this);
    }
}

void Validator::visitEnumeration(Enumeration* enm) {
    checkIdentifier(enm->getName(), enm->getSourceRange().begin);
    namedDeclarations[enm->getName()] = enm;

    if (enm->getValues().empty()) {
        result.addWarning("Enumeration has no values: " + enm->getName(),
                         enm->getSourceRange().begin);
    }

    for (const auto& val : enm->getValues()) {
        val->accept(*this);
    }
}

void Validator::visitEnumerationValue(EnumerationValue* val) {
    checkIdentifier(val->getName(), val->getSourceRange().begin);
}

void Validator::visitParameter(Parameter* param) {
    checkIdentifier(param->getName(), param->getSourceRange().begin);

    if (param->getType()) {
        param->getType()->accept(*this);
    } else {
        result.addError("Parameter has no type: " + param->getName(),
                       param->getSourceRange().begin);
    }
}

void Validator::visitProperty(Property* prop) {
    checkIdentifier(prop->getName(), prop->getSourceRange().begin);

    if (prop->getType()) {
        prop->getType()->accept(*this);
    } else {
        result.addError("Property has no type: " + prop->getName(),
                       prop->getSourceRange().begin);
    }
}

void Validator::visitTypeRef(TypeRef* type) {
    if (!type->isBuiltin()) {
        checkTypeExists(type->getCustomTypeName(), type->getSourceRange().begin);
    }

    if (type->getElementType()) {
        type->getElementType()->accept(*this);
    }
}

// ScriptingLedger implementation
bool ScriptingLedger::registerDefinition(const std::string& identifier,
                                        const std::string& source,
                                        ParserFactory::Format format,
                                        const std::string& filename) {
    diagnostics.clear();

    // Create context for this definition
    auto context = std::make_unique<ASTContext>();
    ASTContext* ctxPtr = context.get();

    // Parse the source
    auto doc = ParserFactory::parse(format, source, filename, ctxPtr, &diagnostics);

    if (!doc || diagnostics.hasErrors()) {
        return false;
    }

    // Validate the document
    Validator validator;
    ValidationResult validationResult = validator.validate(doc.get());

    // Create ledger entry
    std::string formatStr;
    switch (format) {
        case ParserFactory::Format::SDEF: formatStr = "sdef"; break;
        case ParserFactory::Format::AppleScript: formatStr = "applescript"; break;
        case ParserFactory::Format::JavaScript: formatStr = "javascript"; break;
    }

    auto entry = std::make_unique<LedgerEntry>(identifier, doc, ctxPtr, filename, formatStr);
    entry->setValidationResult(validationResult);

    // Store
    entries[identifier] = std::move(entry);
    contexts[identifier] = std::move(context);

    return true;
}

bool ScriptingLedger::removeDefinition(const std::string& identifier) {
    auto it = entries.find(identifier);
    if (it == entries.end()) {
        return false;
    }

    entries.erase(it);
    contexts.erase(identifier);
    return true;
}

LedgerEntry* ScriptingLedger::getEntry(const std::string& identifier) const {
    auto it = entries.find(identifier);
    return it != entries.end() ? it->second.get() : nullptr;
}

SDEFDocument* ScriptingLedger::getDocument(const std::string& identifier) const {
    auto entry = getEntry(identifier);
    return entry ? entry->getDocument() : nullptr;
}

bool ScriptingLedger::hasDefinition(const std::string& identifier) const {
    return entries.find(identifier) != entries.end();
}

std::vector<std::string> ScriptingLedger::getAllIdentifiers() const {
    std::vector<std::string> ids;
    for (const auto& pair : entries) {
        ids.push_back(pair.first);
    }
    return ids;
}

std::vector<LedgerEntry*> ScriptingLedger::getAllEntries() const {
    std::vector<LedgerEntry*> result;
    for (const auto& pair : entries) {
        result.push_back(pair.second.get());
    }
    return result;
}

ValidationResult ScriptingLedger::validateDefinition(const std::string& identifier) {
    auto entry = getEntry(identifier);
    if (!entry) {
        ValidationResult result;
        result.addError("Definition not found: " + identifier);
        return result;
    }

    Validator validator;
    ValidationResult validationResult = validator.validate(entry->getDocument());
    entry->setValidationResult(validationResult);

    return validationResult;
}

bool ScriptingLedger::validateAll() {
    bool allValid = true;

    for (auto& pair : entries) {
        ValidationResult result = validateDefinition(pair.first);
        if (!result.isValid()) {
            allValid = false;
        }
    }

    return allValid;
}

Command* ScriptingLedger::findCommand(const std::string& identifier,
                                     const std::string& commandName) const {
    auto doc = getDocument(identifier);
    if (!doc) return nullptr;

    for (const auto& suite : doc->getSuites()) {
        for (const auto& cmd : suite->getCommands()) {
            if (cmd->getName() == commandName) {
                return cmd.get();
            }
        }
    }

    return nullptr;
}

Class* ScriptingLedger::findClass(const std::string& identifier,
                                 const std::string& className) const {
    auto doc = getDocument(identifier);
    if (!doc) return nullptr;

    for (const auto& suite : doc->getSuites()) {
        for (const auto& cls : suite->getClasses()) {
            if (cls->getName() == className) {
                return cls.get();
            }
        }
    }

    return nullptr;
}

Suite* ScriptingLedger::findSuite(const std::string& identifier,
                                 const std::string& suiteName) const {
    auto doc = getDocument(identifier);
    if (!doc) return nullptr;

    for (const auto& suite : doc->getSuites()) {
        if (suite->getName() == suiteName) {
            return suite.get();
        }
    }

    return nullptr;
}

std::string ScriptingLedger::generateSDEF(const std::string& identifier) const {
    auto doc = getDocument(identifier);
    if (!doc) return "";

    CodeGenerator generator(CodeGenerator::OutputFormat::SDEF);
    return generator.generate(doc);
}

std::string ScriptingLedger::generateAppleScript(const std::string& identifier) const {
    auto doc = getDocument(identifier);
    if (!doc) return "";

    CodeGenerator generator(CodeGenerator::OutputFormat::AppleScript);
    return generator.generate(doc);
}

std::string ScriptingLedger::generateJavaScript(const std::string& identifier) const {
    auto doc = getDocument(identifier);
    if (!doc) return "";

    CodeGenerator generator(CodeGenerator::OutputFormat::JavaScript);
    return generator.generate(doc);
}

size_t ScriptingLedger::getTotalCommandCount() const {
    size_t count = 0;
    for (const auto& pair : entries) {
        auto doc = pair.second->getDocument();
        for (const auto& suite : doc->getSuites()) {
            count += suite->getCommands().size();
        }
    }
    return count;
}

size_t ScriptingLedger::getTotalClassCount() const {
    size_t count = 0;
    for (const auto& pair : entries) {
        auto doc = pair.second->getDocument();
        for (const auto& suite : doc->getSuites()) {
            count += suite->getClasses().size();
        }
    }
    return count;
}

// CodeGenerator implementation
void CodeGenerator::indent() {
    for (int i = 0; i < indentLevel; i++) {
        output << "  ";
    }
}

void CodeGenerator::emitLine(const std::string& line) {
    output << line << "\n";
}

void CodeGenerator::emitIndented(const std::string& line) {
    indent();
    emitLine(line);
}

std::string CodeGenerator::generate(SDEFDocument* doc) {
    output.str("");
    output.clear();
    indentLevel = 0;

    doc->accept(*this);
    return output.str();
}

void CodeGenerator::visitSDEFDocument(SDEFDocument* doc) {
    if (format == OutputFormat::SDEF) {
        emitLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        emitLine("<!DOCTYPE dictionary SYSTEM \"file://localhost/System/Library/DTDs/sdef.dtd\">");
        emitLine("<dictionary title=\"" + doc->getTitle() + "\">");
        indentLevel++;

        for (const auto& suite : doc->getSuites()) {
            suite->accept(*this);
        }

        indentLevel--;
        emitLine("</dictionary>");
    }
}

void CodeGenerator::visitSuite(Suite* suite) {
    if (format == OutputFormat::SDEF) {
        emitIndented("<suite name=\"" + suite->getName() + "\" code=\"" +
                    suite->getCode() + "\" description=\"" + suite->getDocumentation() + "\">");
        indentLevel++;

        for (const auto& cmd : suite->getCommands()) {
            cmd->accept(*this);
        }

        for (const auto& cls : suite->getClasses()) {
            cls->accept(*this);
        }

        indentLevel--;
        emitIndented("</suite>");
    }
}

void CodeGenerator::visitCommand(Command* cmd) {
    if (format == OutputFormat::SDEF) {
        emitIndented("<command name=\"" + cmd->getName() + "\" code=\"" + cmd->getCode() +
                    "\" description=\"" + cmd->getDocumentation() + "\">");
        indentLevel++;

        for (const auto& param : cmd->getParameters()) {
            param->accept(*this);
        }

        if (cmd->getReturnType()) {
            emitIndented("<result type=\"" + cmd->getReturnType()->toString() + "\"/>");
        }

        indentLevel--;
        emitIndented("</command>");
    }
}

void CodeGenerator::visitClass(Class* cls) {
    if (format == OutputFormat::SDEF) {
        std::string inherits = cls->getInheritsFrom().empty() ? "" :
                              " inherits=\"" + cls->getInheritsFrom() + "\"";
        emitIndented("<class name=\"" + cls->getName() + "\" code=\"" + cls->getCode() +
                    "\"" + inherits + " description=\"" + cls->getDocumentation() + "\">");
        indentLevel++;

        for (const auto& prop : cls->getProperties()) {
            prop->accept(*this);
        }

        indentLevel--;
        emitIndented("</class>");
    }
}

void CodeGenerator::visitEnumeration(Enumeration* enm) {
    if (format == OutputFormat::SDEF) {
        emitIndented("<enumeration name=\"" + enm->getName() + "\" code=\"" + enm->getCode() + "\">");
        indentLevel++;

        for (const auto& val : enm->getValues()) {
            val->accept(*this);
        }

        indentLevel--;
        emitIndented("</enumeration>");
    }
}

void CodeGenerator::visitEnumerationValue(EnumerationValue* val) {
    if (format == OutputFormat::SDEF) {
        emitIndented("<enumerator name=\"" + val->getName() + "\" code=\"" + val->getCode() + "\"/>");
    }
}

void CodeGenerator::visitParameter(Parameter* param) {
    if (format == OutputFormat::SDEF) {
        std::string optional = param->getIsOptional() ? " optional=\"yes\"" : "";
        emitIndented("<parameter name=\"" + param->getName() + "\" code=\"" + param->getCode() +
                    "\" type=\"" + (param->getType() ? param->getType()->toString() : "any") +
                    "\"" + optional + " description=\"" + param->getDocumentation() + "\"/>");
    }
}

void CodeGenerator::visitProperty(Property* prop) {
    if (format == OutputFormat::SDEF) {
        std::string access = prop->getIsReadOnly() ? " access=\"r\"" : "";
        emitIndented("<property name=\"" + prop->getName() + "\" code=\"" + prop->getCode() +
                    "\" type=\"" + (prop->getType() ? prop->getType()->toString() : "any") +
                    "\"" + access + " description=\"" + prop->getDocumentation() + "\"/>");
    }
}

void CodeGenerator::visitTypeRef(TypeRef* type) {
    // Type refs are handled inline
}

} // namespace Scripting
} // namespace PlugInKit
