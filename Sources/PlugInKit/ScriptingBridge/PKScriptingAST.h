//
//  PKScriptingAST.h
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//
//  LLVM-based Abstract Syntax Tree for Scripting Definitions

#ifndef PKScriptingAST_h
#define PKScriptingAST_h

#include <string>
#include <vector>
#include <memory>
#include <map>

namespace PlugInKit {
namespace Scripting {

// Forward declarations
class ASTContext;
class ASTVisitor;

// Base AST node types
enum class ASTNodeKind {
    // Documents
    SDEFDocument,
    AppleScriptDocument,
    JavaScriptDocument,

    // Structure
    Suite,
    Command,
    Class,
    Enumeration,

    // Members
    Parameter,
    Property,
    Element,
    EnumerationValue,

    // Types
    TypeRef,
    RecordType,
    ListType,

    // Metadata
    Documentation,
    Synonym
};

// Source location for error reporting
struct SourceLocation {
    std::string filename;
    unsigned line;
    unsigned column;

    SourceLocation() : line(0), column(0) {}
    SourceLocation(const std::string& file, unsigned l, unsigned c)
        : filename(file), line(l), column(c) {}

    bool isValid() const { return line > 0; }
};

// Source range
struct SourceRange {
    SourceLocation begin;
    SourceLocation end;

    SourceRange() {}
    SourceRange(const SourceLocation& b, const SourceLocation& e)
        : begin(b), end(e) {}

    bool isValid() const { return begin.isValid() && end.isValid(); }
};

// Base AST node
class ASTNode {
protected:
    ASTNodeKind kind;
    SourceRange sourceRange;
    ASTContext* context;

public:
    ASTNode(ASTNodeKind k, ASTContext* ctx = nullptr)
        : kind(k), context(ctx) {}

    virtual ~ASTNode() = default;

    ASTNodeKind getKind() const { return kind; }
    SourceRange getSourceRange() const { return sourceRange; }
    void setSourceRange(const SourceRange& range) { sourceRange = range; }

    ASTContext* getContext() const { return context; }
    void setContext(ASTContext* ctx) { context = ctx; }

    // Visitor pattern
    virtual void accept(ASTVisitor& visitor) = 0;

    // RTTI helpers
    template<typename T>
    bool isa() const;

    template<typename T>
    T* cast();

    template<typename T>
    const T* cast() const;
};

// Named declarations
class NamedDecl : public ASTNode {
protected:
    std::string name;
    std::string code;  // Four-char code for AppleScript
    std::string documentation;

public:
    NamedDecl(ASTNodeKind k, const std::string& n, ASTContext* ctx = nullptr)
        : ASTNode(k, ctx), name(n) {}

    const std::string& getName() const { return name; }
    void setName(const std::string& n) { name = n; }

    const std::string& getCode() const { return code; }
    void setCode(const std::string& c) { code = c; }

    const std::string& getDocumentation() const { return documentation; }
    void setDocumentation(const std::string& doc) { documentation = doc; }
};

// Type reference
class TypeRef : public ASTNode {
public:
    enum class BuiltinType {
        Void,
        Boolean,
        Integer,
        Real,
        Text,
        Date,
        Data,
        Any,
        Object,
        List,
        Record,
        Custom
    };

private:
    BuiltinType builtinType;
    std::string customTypeName;
    std::shared_ptr<TypeRef> elementType;  // For lists

public:
    TypeRef(BuiltinType type, ASTContext* ctx = nullptr)
        : ASTNode(ASTNodeKind::TypeRef, ctx), builtinType(type) {}

    TypeRef(const std::string& customType, ASTContext* ctx = nullptr)
        : ASTNode(ASTNodeKind::TypeRef, ctx),
          builtinType(BuiltinType::Custom),
          customTypeName(customType) {}

    BuiltinType getBuiltinType() const { return builtinType; }
    const std::string& getCustomTypeName() const { return customTypeName; }

    bool isBuiltin() const { return builtinType != BuiltinType::Custom; }
    bool isList() const { return builtinType == BuiltinType::List; }
    bool isRecord() const { return builtinType == BuiltinType::Record; }

    void setElementType(std::shared_ptr<TypeRef> type) { elementType = type; }
    std::shared_ptr<TypeRef> getElementType() const { return elementType; }

    void accept(ASTVisitor& visitor) override;

    std::string toString() const;
};

// Parameter
class Parameter : public NamedDecl {
private:
    std::shared_ptr<TypeRef> type;
    bool isOptional;
    std::string defaultValue;

public:
    Parameter(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::Parameter, name, ctx),
          isOptional(false) {}

    void setType(std::shared_ptr<TypeRef> t) { type = t; }
    std::shared_ptr<TypeRef> getType() const { return type; }

    bool getIsOptional() const { return isOptional; }
    void setIsOptional(bool opt) { isOptional = opt; }

    const std::string& getDefaultValue() const { return defaultValue; }
    void setDefaultValue(const std::string& val) { defaultValue = val; }

    void accept(ASTVisitor& visitor) override;
};

// Property (for classes)
class Property : public NamedDecl {
private:
    std::shared_ptr<TypeRef> type;
    bool isReadOnly;

public:
    Property(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::Property, name, ctx),
          isReadOnly(false) {}

    void setType(std::shared_ptr<TypeRef> t) { type = t; }
    std::shared_ptr<TypeRef> getType() const { return type; }

    bool getIsReadOnly() const { return isReadOnly; }
    void setIsReadOnly(bool readOnly) { isReadOnly = readOnly; }

    void accept(ASTVisitor& visitor) override;
};

// Command
class Command : public NamedDecl {
private:
    std::vector<std::shared_ptr<Parameter>> parameters;
    std::shared_ptr<TypeRef> returnType;

public:
    Command(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::Command, name, ctx) {}

    void addParameter(std::shared_ptr<Parameter> param) {
        parameters.push_back(param);
    }

    const std::vector<std::shared_ptr<Parameter>>& getParameters() const {
        return parameters;
    }

    void setReturnType(std::shared_ptr<TypeRef> type) { returnType = type; }
    std::shared_ptr<TypeRef> getReturnType() const { return returnType; }

    void accept(ASTVisitor& visitor) override;
};

// Class
class Class : public NamedDecl {
private:
    std::vector<std::shared_ptr<Property>> properties;
    std::string inheritsFrom;

public:
    Class(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::Class, name, ctx) {}

    void addProperty(std::shared_ptr<Property> prop) {
        properties.push_back(prop);
    }

    const std::vector<std::shared_ptr<Property>>& getProperties() const {
        return properties;
    }

    void setInheritsFrom(const std::string& baseClass) {
        inheritsFrom = baseClass;
    }

    const std::string& getInheritsFrom() const { return inheritsFrom; }

    void accept(ASTVisitor& visitor) override;
};

// Enumeration value
class EnumerationValue : public NamedDecl {
public:
    EnumerationValue(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::EnumerationValue, name, ctx) {}

    void accept(ASTVisitor& visitor) override;
};

// Enumeration
class Enumeration : public NamedDecl {
private:
    std::vector<std::shared_ptr<EnumerationValue>> values;

public:
    Enumeration(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::Enumeration, name, ctx) {}

    void addValue(std::shared_ptr<EnumerationValue> value) {
        values.push_back(value);
    }

    const std::vector<std::shared_ptr<EnumerationValue>>& getValues() const {
        return values;
    }

    void accept(ASTVisitor& visitor) override;
};

// Suite (collection of commands and classes)
class Suite : public NamedDecl {
private:
    std::vector<std::shared_ptr<Command>> commands;
    std::vector<std::shared_ptr<Class>> classes;
    std::vector<std::shared_ptr<Enumeration>> enumerations;

public:
    Suite(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::Suite, name, ctx) {}

    void addCommand(std::shared_ptr<Command> cmd) {
        commands.push_back(cmd);
    }

    void addClass(std::shared_ptr<Class> cls) {
        classes.push_back(cls);
    }

    void addEnumeration(std::shared_ptr<Enumeration> enm) {
        enumerations.push_back(enm);
    }

    const std::vector<std::shared_ptr<Command>>& getCommands() const {
        return commands;
    }

    const std::vector<std::shared_ptr<Class>>& getClasses() const {
        return classes;
    }

    const std::vector<std::shared_ptr<Enumeration>>& getEnumerations() const {
        return enumerations;
    }

    void accept(ASTVisitor& visitor) override;
};

// Document (root node)
class SDEFDocument : public NamedDecl {
private:
    std::vector<std::shared_ptr<Suite>> suites;
    std::string title;

public:
    SDEFDocument(const std::string& name, ASTContext* ctx = nullptr)
        : NamedDecl(ASTNodeKind::SDEFDocument, name, ctx) {}

    void addSuite(std::shared_ptr<Suite> suite) {
        suites.push_back(suite);
    }

    const std::vector<std::shared_ptr<Suite>>& getSuites() const {
        return suites;
    }

    void setTitle(const std::string& t) { title = t; }
    const std::string& getTitle() const { return title; }

    void accept(ASTVisitor& visitor) override;
};

// Visitor pattern for AST traversal
class ASTVisitor {
public:
    virtual ~ASTVisitor() = default;

    virtual void visitSDEFDocument(SDEFDocument* doc) = 0;
    virtual void visitSuite(Suite* suite) = 0;
    virtual void visitCommand(Command* cmd) = 0;
    virtual void visitClass(Class* cls) = 0;
    virtual void visitEnumeration(Enumeration* enm) = 0;
    virtual void visitEnumerationValue(EnumerationValue* val) = 0;
    virtual void visitParameter(Parameter* param) = 0;
    virtual void visitProperty(Property* prop) = 0;
    virtual void visitTypeRef(TypeRef* type) = 0;
};

// AST Context (memory management and shared state)
class ASTContext {
private:
    std::vector<std::unique_ptr<ASTNode>> nodes;
    std::map<std::string, ASTNode*> namedDecls;

public:
    ASTContext() = default;
    ~ASTContext() = default;

    // Non-copyable
    ASTContext(const ASTContext&) = delete;
    ASTContext& operator=(const ASTContext&) = delete;

    template<typename T, typename... Args>
    T* create(Args&&... args) {
        auto node = std::make_unique<T>(std::forward<Args>(args)...);
        node->setContext(this);
        T* ptr = node.get();
        nodes.push_back(std::move(node));
        return ptr;
    }

    void registerNamedDecl(const std::string& name, ASTNode* node) {
        namedDecls[name] = node;
    }

    ASTNode* lookupNamedDecl(const std::string& name) const {
        auto it = namedDecls.find(name);
        return it != namedDecls.end() ? it->second : nullptr;
    }

    size_t getNodeCount() const { return nodes.size(); }
};

} // namespace Scripting
} // namespace PlugInKit

#endif /* PKScriptingAST_h */
