//
//  PKScriptingParser.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//
//  LLVM-based parser for scripting definitions

#ifndef PKScriptingParser_h
#define PKScriptingParser_h

#include "PKScriptingAST.h"
#include <string>
#include <vector>
#include <memory>

namespace PlugInKit {
namespace Scripting {

// Diagnostic message
struct Diagnostic {
    enum class Severity {
        Note,
        Warning,
        Error
    };

    Severity severity;
    SourceLocation location;
    std::string message;

    Diagnostic(Severity sev, const SourceLocation& loc, const std::string& msg)
        : severity(sev), location(loc), message(msg) {}

    std::string toString() const;
};

// Diagnostic engine
class DiagnosticEngine {
private:
    std::vector<Diagnostic> diagnostics;
    unsigned errorCount;
    unsigned warningCount;

public:
    DiagnosticEngine() : errorCount(0), warningCount(0) {}

    void report(Diagnostic::Severity severity, const SourceLocation& loc, const std::string& msg) {
        diagnostics.emplace_back(severity, loc, msg);
        if (severity == Diagnostic::Severity::Error) {
            errorCount++;
        } else if (severity == Diagnostic::Severity::Warning) {
            warningCount++;
        }
    }

    void reportError(const SourceLocation& loc, const std::string& msg) {
        report(Diagnostic::Severity::Error, loc, msg);
    }

    void reportWarning(const SourceLocation& loc, const std::string& msg) {
        report(Diagnostic::Severity::Warning, loc, msg);
    }

    void reportNote(const SourceLocation& loc, const std::string& msg) {
        report(Diagnostic::Severity::Note, loc, msg);
    }

    const std::vector<Diagnostic>& getDiagnostics() const { return diagnostics; }
    unsigned getErrorCount() const { return errorCount; }
    unsigned getWarningCount() const { return warningCount; }
    bool hasErrors() const { return errorCount > 0; }

    void clear() {
        diagnostics.clear();
        errorCount = 0;
        warningCount = 0;
    }
};

// Token types for lexer
enum class TokenKind {
    // Literals
    Identifier,
    StringLiteral,
    NumberLiteral,

    // XML tokens
    LessThan,           // <
    GreaterThan,        // >
    LessSlash,          // </
    SlashGreater,       // />
    Equals,             // =
    QuestionGreater,    // ?>

    // Keywords (SDEF elements)
    KW_Dictionary,
    KW_Suite,
    KW_Command,
    KW_Class,
    KW_Property,
    KW_Parameter,
    KW_Result,
    KW_Enumeration,
    KW_Enumerator,

    // Special
    XMLDecl,
    Comment,
    EndOfFile,
    Invalid
};

// Token
struct Token {
    TokenKind kind;
    std::string text;
    SourceLocation location;

    Token(TokenKind k = TokenKind::Invalid)
        : kind(k) {}

    Token(TokenKind k, const std::string& t, const SourceLocation& loc)
        : kind(k), text(t), location(loc) {}

    bool is(TokenKind k) const { return kind == k; }
    bool isNot(TokenKind k) const { return kind != k; }
};

// Lexer
class Lexer {
private:
    std::string buffer;
    size_t position;
    unsigned line;
    unsigned column;
    std::string filename;
    DiagnosticEngine* diagnostics;

    char peek() const;
    char advance();
    void skipWhitespace();
    Token lexXMLTag();
    Token lexString();
    Token lexNumber();
    Token lexIdentifier();

public:
    Lexer(const std::string& input, const std::string& file, DiagnosticEngine* diag)
        : buffer(input), position(0), line(1), column(1),
          filename(file), diagnostics(diag) {}

    Token nextToken();
    SourceLocation getCurrentLocation() const;
};

// Parser for SDEF (Scripting Definition) XML format
class SDEFParser {
private:
    Lexer lexer;
    Token currentToken;
    ASTContext* context;
    DiagnosticEngine* diagnostics;

    void advance();
    bool expect(TokenKind kind, const std::string& message);
    std::string parseAttribute(const std::string& name);
    std::map<std::string, std::string> parseAttributes();

    std::shared_ptr<TypeRef> parseTypeAttribute(const std::string& typeStr);
    std::shared_ptr<Parameter> parseParameter();
    std::shared_ptr<Property> parseProperty();
    std::shared_ptr<Command> parseCommand();
    std::shared_ptr<Class> parseClass();
    std::shared_ptr<EnumerationValue> parseEnumerator();
    std::shared_ptr<Enumeration> parseEnumeration();
    std::shared_ptr<Suite> parseSuite();

public:
    SDEFParser(const std::string& input, const std::string& filename,
               ASTContext* ctx, DiagnosticEngine* diag)
        : lexer(input, filename, diag), context(ctx), diagnostics(diag) {
        advance();
    }

    std::shared_ptr<SDEFDocument> parseDocument();
};

// Parser factory for different formats
class ParserFactory {
public:
    enum class Format {
        SDEF,
        AppleScript,
        JavaScript
    };

    static std::shared_ptr<SDEFDocument> parse(Format format,
                                               const std::string& input,
                                               const std::string& filename,
                                               ASTContext* context,
                                               DiagnosticEngine* diagnostics);
};

} // namespace Scripting
} // namespace PlugInKit

#endif /* PKScriptingParser_h */
