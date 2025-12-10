//
//  PKScriptingParser.cpp
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#include "PKScriptingParser.h"
#include <sstream>
#include <cctype>

namespace PlugInKit {
namespace Scripting {

// Diagnostic implementation
std::string Diagnostic::toString() const {
    std::ostringstream oss;
    oss << location.filename << ":" << location.line << ":" << location.column << ": ";

    switch (severity) {
        case Severity::Error: oss << "error: "; break;
        case Severity::Warning: oss << "warning: "; break;
        case Severity::Note: oss << "note: "; break;
    }

    oss << message;
    return oss.str();
}

// Lexer implementation
char Lexer::peek() const {
    if (position >= buffer.size()) {
        return '\0';
    }
    return buffer[position];
}

char Lexer::advance() {
    if (position >= buffer.size()) {
        return '\0';
    }

    char c = buffer[position++];
    if (c == '\n') {
        line++;
        column = 1;
    } else {
        column++;
    }
    return c;
}

void Lexer::skipWhitespace() {
    while (std::isspace(peek())) {
        advance();
    }
}

SourceLocation Lexer::getCurrentLocation() const {
    return SourceLocation(filename, line, column);
}

Token Lexer::lexString() {
    SourceLocation startLoc = getCurrentLocation();
    char quote = advance(); // Skip opening quote
    std::string str;

    while (peek() != quote && peek() != '\0') {
        if (peek() == '\\') {
            advance();
            char escaped = advance();
            switch (escaped) {
                case 'n': str += '\n'; break;
                case 't': str += '\t'; break;
                case 'r': str += '\r'; break;
                case '\\': str += '\\'; break;
                case '"': str += '"'; break;
                case '\'': str += '\''; break;
                default: str += escaped; break;
            }
        } else {
            str += advance();
        }
    }

    if (peek() == quote) {
        advance(); // Skip closing quote
    } else {
        diagnostics->reportError(startLoc, "Unterminated string literal");
    }

    return Token(TokenKind::StringLiteral, str, startLoc);
}

Token Lexer::lexNumber() {
    SourceLocation startLoc = getCurrentLocation();
    std::string num;

    while (std::isdigit(peek()) || peek() == '.') {
        num += advance();
    }

    return Token(TokenKind::NumberLiteral, num, startLoc);
}

Token Lexer::lexIdentifier() {
    SourceLocation startLoc = getCurrentLocation();
    std::string id;

    while (std::isalnum(peek()) || peek() == '_' || peek() == '-') {
        id += advance();
    }

    // Check for keywords
    if (id == "dictionary") return Token(TokenKind::KW_Dictionary, id, startLoc);
    if (id == "suite") return Token(TokenKind::KW_Suite, id, startLoc);
    if (id == "command") return Token(TokenKind::KW_Command, id, startLoc);
    if (id == "class") return Token(TokenKind::KW_Class, id, startLoc);
    if (id == "property") return Token(TokenKind::KW_Property, id, startLoc);
    if (id == "parameter") return Token(TokenKind::KW_Parameter, id, startLoc);
    if (id == "result") return Token(TokenKind::KW_Result, id, startLoc);
    if (id == "enumeration") return Token(TokenKind::KW_Enumeration, id, startLoc);
    if (id == "enumerator") return Token(TokenKind::KW_Enumerator, id, startLoc);

    return Token(TokenKind::Identifier, id, startLoc);
}

Token Lexer::nextToken() {
    skipWhitespace();

    if (position >= buffer.size()) {
        return Token(TokenKind::EndOfFile, "", getCurrentLocation());
    }

    SourceLocation loc = getCurrentLocation();
    char c = peek();

    // XML special characters
    if (c == '<') {
        advance();
        if (peek() == '/') {
            advance();
            return Token(TokenKind::LessSlash, "</", loc);
        }
        if (peek() == '?') {
            // Skip XML declaration
            while (peek() != '\0' && !(peek() == '?' && buffer[position + 1] == '>')) {
                advance();
            }
            if (peek() == '?') {
                advance(); // ?
                advance(); // >
            }
            return nextToken(); // Skip and get next token
        }
        if (peek() == '!') {
            // Comment or DOCTYPE
            advance();
            if (peek() == '-' && buffer[position + 1] == '-') {
                // Comment
                advance(); advance(); // Skip --
                while (peek() != '\0' && !(peek() == '-' && buffer[position + 1] == '-')) {
                    advance();
                }
                if (peek() == '-') {
                    advance(); advance(); // Skip --
                    if (peek() == '>') advance(); // Skip >
                }
                return nextToken(); // Skip comment
            } else {
                // DOCTYPE - skip entire declaration
                int depth = 1;
                while (peek() != '\0' && depth > 0) {
                    if (peek() == '<') depth++;
                    else if (peek() == '>') depth--;
                    advance();
                }
                return nextToken(); // Skip and get next token
            }
        }
        return Token(TokenKind::LessThan, "<", loc);
    }

    if (c == '>') {
        advance();
        return Token(TokenKind::GreaterThan, ">", loc);
    }

    if (c == '/') {
        advance();
        if (peek() == '>') {
            advance();
            return Token(TokenKind::SlashGreater, "/>", loc);
        }
        return Token(TokenKind::Invalid, "/", loc);
    }

    if (c == '=') {
        advance();
        return Token(TokenKind::Equals, "=", loc);
    }

    if (c == '"' || c == '\'') {
        return lexString();
    }

    if (std::isdigit(c)) {
        return lexNumber();
    }

    if (std::isalpha(c) || c == '_') {
        return lexIdentifier();
    }

    // Unknown character
    advance();
    diagnostics->reportError(loc, std::string("Unexpected character: ") + c);
    return Token(TokenKind::Invalid, std::string(1, c), loc);
}

// SDEFParser implementation
void SDEFParser::advance() {
    currentToken = lexer.nextToken();
}

bool SDEFParser::expect(TokenKind kind, const std::string& message) {
    if (currentToken.kind != kind) {
        diagnostics->reportError(currentToken.location, message);
        return false;
    }
    advance();
    return true;
}

std::map<std::string, std::string> SDEFParser::parseAttributes() {
    std::map<std::string, std::string> attrs;

    while (currentToken.kind == TokenKind::Identifier) {
        std::string attrName = currentToken.text;
        advance();

        if (currentToken.kind == TokenKind::Equals) {
            advance();

            if (currentToken.kind == TokenKind::StringLiteral) {
                attrs[attrName] = currentToken.text;
                advance();
            } else {
                diagnostics->reportError(currentToken.location,
                    "Expected string literal for attribute value");
            }
        }
    }

    return attrs;
}

std::shared_ptr<TypeRef> SDEFParser::parseTypeAttribute(const std::string& typeStr) {
    if (typeStr == "boolean") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Boolean, context);
    } else if (typeStr == "integer") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Integer, context);
    } else if (typeStr == "real") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Real, context);
    } else if (typeStr == "text") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Text, context);
    } else if (typeStr == "date") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Date, context);
    } else if (typeStr == "data") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Data, context);
    } else if (typeStr == "any") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Any, context);
    } else if (typeStr == "list") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::List, context);
    } else if (typeStr == "record") {
        return std::make_shared<TypeRef>(TypeRef::BuiltinType::Record, context);
    } else {
        // Custom type
        return std::make_shared<TypeRef>(typeStr, context);
    }
}

std::shared_ptr<Parameter> SDEFParser::parseParameter() {
    expect(TokenKind::LessThan, "Expected '<'");
    expect(TokenKind::KW_Parameter, "Expected 'parameter'");

    auto attrs = parseAttributes();
    auto param = std::make_shared<Parameter>(attrs["name"], context);

    if (!attrs["code"].empty()) {
        param->setCode(attrs["code"]);
    }
    if (!attrs["type"].empty()) {
        param->setType(parseTypeAttribute(attrs["type"]));
    }
    if (!attrs["description"].empty()) {
        param->setDocumentation(attrs["description"]);
    }
    if (attrs["optional"] == "yes") {
        param->setIsOptional(true);
    }

    // Handle self-closing or closing tag
    if (currentToken.kind == TokenKind::SlashGreater) {
        advance();
    } else {
        expect(TokenKind::GreaterThan, "Expected '>'");
        // Parse nested content if needed
        if (currentToken.kind == TokenKind::LessSlash) {
            advance();
            expect(TokenKind::KW_Parameter, "Expected closing 'parameter'");
            expect(TokenKind::GreaterThan, "Expected '>'");
        }
    }

    return param;
}

std::shared_ptr<Property> SDEFParser::parseProperty() {
    expect(TokenKind::LessThan, "Expected '<'");
    expect(TokenKind::KW_Property, "Expected 'property'");

    auto attrs = parseAttributes();
    auto prop = std::make_shared<Property>(attrs["name"], context);

    if (!attrs["code"].empty()) {
        prop->setCode(attrs["code"]);
    }
    if (!attrs["type"].empty()) {
        prop->setType(parseTypeAttribute(attrs["type"]));
    }
    if (!attrs["description"].empty()) {
        prop->setDocumentation(attrs["description"]);
    }
    if (attrs["access"] == "r") {
        prop->setIsReadOnly(true);
    }

    if (currentToken.kind == TokenKind::SlashGreater) {
        advance();
    } else {
        expect(TokenKind::GreaterThan, "Expected '>'");
        if (currentToken.kind == TokenKind::LessSlash) {
            advance();
            expect(TokenKind::KW_Property, "Expected closing 'property'");
            expect(TokenKind::GreaterThan, "Expected '>'");
        }
    }

    return prop;
}

std::shared_ptr<Command> SDEFParser::parseCommand() {
    expect(TokenKind::LessThan, "Expected '<'");
    expect(TokenKind::KW_Command, "Expected 'command'");

    auto attrs = parseAttributes();
    auto cmd = std::make_shared<Command>(attrs["name"], context);

    if (!attrs["code"].empty()) {
        cmd->setCode(attrs["code"]);
    }
    if (!attrs["description"].empty()) {
        cmd->setDocumentation(attrs["description"]);
    }

    if (currentToken.kind == TokenKind::SlashGreater) {
        advance();
        return cmd;
    }

    expect(TokenKind::GreaterThan, "Expected '>'");

    // Parse nested parameters and result
    while (currentToken.kind == TokenKind::LessThan) {
        size_t savedPos = lexer.getCurrentLocation().column;
        advance(); // consume <

        if (currentToken.kind == TokenKind::KW_Parameter) {
            // Back up to re-parse with parseParameter
            currentToken = Token(TokenKind::LessThan, "<", lexer.getCurrentLocation());
            cmd->addParameter(parseParameter());
        } else if (currentToken.kind == TokenKind::KW_Result) {
            auto resultAttrs = parseAttributes();
            if (!resultAttrs["type"].empty()) {
                cmd->setReturnType(parseTypeAttribute(resultAttrs["type"]));
            }
            if (currentToken.kind == TokenKind::SlashGreater) {
                advance();
            } else {
                expect(TokenKind::GreaterThan, "Expected '>'");
                if (currentToken.kind == TokenKind::LessSlash) {
                    advance();
                    expect(TokenKind::KW_Result, "Expected closing 'result'");
                    expect(TokenKind::GreaterThan, "Expected '>'");
                }
            }
        } else if (currentToken.kind == TokenKind::SlashGreater) {
            break; // End of command
        } else {
            // Check for closing tag
            if (currentToken.kind == TokenKind::Identifier && currentToken.text == "command") {
                expect(TokenKind::GreaterThan, "Expected '>'");
                return cmd;
            }
            // Skip unknown elements
            while (currentToken.kind != TokenKind::GreaterThan &&
                   currentToken.kind != TokenKind::EndOfFile) {
                advance();
            }
            if (currentToken.kind == TokenKind::GreaterThan) {
                advance();
            }
        }
    }

    // Closing tag
    if (currentToken.kind == TokenKind::LessSlash) {
        advance();
        expect(TokenKind::KW_Command, "Expected closing 'command'");
        expect(TokenKind::GreaterThan, "Expected '>'");
    }

    return cmd;
}

std::shared_ptr<Class> SDEFParser::parseClass() {
    expect(TokenKind::LessThan, "Expected '<'");
    expect(TokenKind::KW_Class, "Expected 'class'");

    auto attrs = parseAttributes();
    auto cls = std::make_shared<Class>(attrs["name"], context);

    if (!attrs["code"].empty()) {
        cls->setCode(attrs["code"]);
    }
    if (!attrs["description"].empty()) {
        cls->setDocumentation(attrs["description"]);
    }
    if (!attrs["inherits"].empty()) {
        cls->setInheritsFrom(attrs["inherits"]);
    }

    if (currentToken.kind == TokenKind::SlashGreater) {
        advance();
        return cls;
    }

    expect(TokenKind::GreaterThan, "Expected '>'");

    // Parse properties
    while (currentToken.kind == TokenKind::LessThan) {
        advance();
        if (currentToken.kind == TokenKind::KW_Property) {
            currentToken = Token(TokenKind::LessThan, "<", lexer.getCurrentLocation());
            cls->addProperty(parseProperty());
        } else if (currentToken.kind == TokenKind::Identifier && currentToken.text == "class") {
            expect(TokenKind::GreaterThan, "Expected '>'");
            return cls;
        } else {
            // Skip unknown elements
            while (currentToken.kind != TokenKind::GreaterThan &&
                   currentToken.kind != TokenKind::EndOfFile) {
                advance();
            }
            if (currentToken.kind == TokenKind::GreaterThan) {
                advance();
            }
        }
    }

    if (currentToken.kind == TokenKind::LessSlash) {
        advance();
        expect(TokenKind::KW_Class, "Expected closing 'class'");
        expect(TokenKind::GreaterThan, "Expected '>'");
    }

    return cls;
}

std::shared_ptr<Suite> SDEFParser::parseSuite() {
    expect(TokenKind::LessThan, "Expected '<'");
    expect(TokenKind::KW_Suite, "Expected 'suite'");

    auto attrs = parseAttributes();
    auto suite = std::make_shared<Suite>(attrs["name"], context);

    if (!attrs["code"].empty()) {
        suite->setCode(attrs["code"]);
    }
    if (!attrs["description"].empty()) {
        suite->setDocumentation(attrs["description"]);
    }

    expect(TokenKind::GreaterThan, "Expected '>'");

    // Parse suite contents
    while (currentToken.kind != TokenKind::EndOfFile) {
        if (currentToken.kind == TokenKind::LessThan) {
            advance();

            if (currentToken.kind == TokenKind::KW_Command) {
                currentToken = Token(TokenKind::LessThan, "<", lexer.getCurrentLocation());
                suite->addCommand(parseCommand());
            } else if (currentToken.kind == TokenKind::KW_Class) {
                currentToken = Token(TokenKind::LessThan, "<", lexer.getCurrentLocation());
                suite->addClass(parseClass());
            } else if (currentToken.kind == TokenKind::Identifier && currentToken.text == "suite") {
                expect(TokenKind::GreaterThan, "Expected '>'");
                return suite;
            } else {
                // Skip unknown elements
                while (currentToken.kind != TokenKind::GreaterThan &&
                       currentToken.kind != TokenKind::EndOfFile) {
                    advance();
                }
                if (currentToken.kind == TokenKind::GreaterThan) {
                    advance();
                }
            }
        } else if (currentToken.kind == TokenKind::LessSlash) {
            advance();
            if (currentToken.kind == TokenKind::KW_Suite) {
                advance();
                expect(TokenKind::GreaterThan, "Expected '>'");
                return suite;
            }
        } else {
            advance();
        }
    }

    return suite;
}

std::shared_ptr<SDEFDocument> SDEFParser::parseDocument() {
    auto doc = std::make_shared<SDEFDocument>("", context);

    // Skip to dictionary element
    while (currentToken.kind != TokenKind::EndOfFile) {
        if (currentToken.kind == TokenKind::LessThan) {
            advance();
            if (currentToken.kind == TokenKind::KW_Dictionary) {
                auto attrs = parseAttributes();
                if (!attrs["title"].empty()) {
                    doc->setTitle(attrs["title"]);
                    doc->setName(attrs["title"]);
                }
                expect(TokenKind::GreaterThan, "Expected '>'");
                break;
            }
        } else {
            advance();
        }
    }

    // Parse suites
    while (currentToken.kind != TokenKind::EndOfFile) {
        if (currentToken.kind == TokenKind::LessThan) {
            advance();
            if (currentToken.kind == TokenKind::KW_Suite) {
                currentToken = Token(TokenKind::LessThan, "<", lexer.getCurrentLocation());
                doc->addSuite(parseSuite());
            } else if (currentToken.kind == TokenKind::Identifier && currentToken.text == "dictionary") {
                // Closing dictionary tag
                expect(TokenKind::GreaterThan, "Expected '>'");
                break;
            }
        } else {
            advance();
        }
    }

    return doc;
}

// ParserFactory implementation
std::shared_ptr<SDEFDocument> ParserFactory::parse(Format format,
                                                   const std::string& input,
                                                   const std::string& filename,
                                                   ASTContext* context,
                                                   DiagnosticEngine* diagnostics) {
    switch (format) {
        case Format::SDEF: {
            SDEFParser parser(input, filename, context, diagnostics);
            return parser.parseDocument();
        }
        case Format::AppleScript:
        case Format::JavaScript:
            // Not yet implemented
            diagnostics->reportError(SourceLocation(filename, 0, 0),
                "AppleScript and JavaScript parsing not yet implemented");
            return nullptr;
    }
    return nullptr;
}

} // namespace Scripting
} // namespace PlugInKit
