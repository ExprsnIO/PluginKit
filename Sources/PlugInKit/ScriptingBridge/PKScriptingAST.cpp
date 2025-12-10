//
//  PKScriptingAST.cpp
//  PlugInKit
//
//  Copyright (c) 2025 Rick Holland. All rights reserved.
//

#include "PKScriptingAST.h"
#include <sstream>

namespace PlugInKit {
namespace Scripting {

// TypeRef implementation
void TypeRef::accept(ASTVisitor& visitor) {
    visitor.visitTypeRef(this);
}

std::string TypeRef::toString() const {
    switch (builtinType) {
        case BuiltinType::Void: return "void";
        case BuiltinType::Boolean: return "boolean";
        case BuiltinType::Integer: return "integer";
        case BuiltinType::Real: return "real";
        case BuiltinType::Text: return "text";
        case BuiltinType::Date: return "date";
        case BuiltinType::Data: return "data";
        case BuiltinType::Any: return "any";
        case BuiltinType::Object: return "object";
        case BuiltinType::List:
            if (elementType) {
                return "list of " + elementType->toString();
            }
            return "list";
        case BuiltinType::Record: return "record";
        case BuiltinType::Custom: return customTypeName;
    }
    return "unknown";
}

// Parameter implementation
void Parameter::accept(ASTVisitor& visitor) {
    visitor.visitParameter(this);
}

// Property implementation
void Property::accept(ASTVisitor& visitor) {
    visitor.visitProperty(this);
}

// Command implementation
void Command::accept(ASTVisitor& visitor) {
    visitor.visitCommand(this);
}

// Class implementation
void Class::accept(ASTVisitor& visitor) {
    visitor.visitClass(this);
}

// EnumerationValue implementation
void EnumerationValue::accept(ASTVisitor& visitor) {
    visitor.visitEnumerationValue(this);
}

// Enumeration implementation
void Enumeration::accept(ASTVisitor& visitor) {
    visitor.visitEnumeration(this);
}

// Suite implementation
void Suite::accept(ASTVisitor& visitor) {
    visitor.visitSuite(this);
}

// SDEFDocument implementation
void SDEFDocument::accept(ASTVisitor& visitor) {
    visitor.visitSDEFDocument(this);
}

} // namespace Scripting
} // namespace PlugInKit
