
extension Entity: CustomStringConvertible {

    var description: String {
        return name
    }
}

extension Invalid: CustomStringConvertible {
    var description: String {
        return text
    }
}

extension Comment: CustomStringConvertible {
    var description: String {
        return text
    }
}

extension Ident: CustomStringConvertible {
    var description: String {
        return name
    }
}

extension Literal: CustomStringConvertible {
    var description: String {
        return text
    }
}

extension Unary: CustomStringConvertible {
    var description: String {
        return op.description + expr.description
    }
}

extension Binary: CustomStringConvertible {
    var description: String {
        return lhs.description + " " + op.description + " " + rhs.description
    }
}

extension Ternary: CustomStringConvertible {
    var description: String {
        return cond.description + " ? " + a.description + " : " + b.description
    }
}

extension Paren: CustomStringConvertible {
    var description: String {
        return "(" + expr.description + ")"
    }
}

extension Function: CustomStringConvertible {
    var description: String {
        return "fn(" + args.map({ $0.description }).joined(separator: ", ") + ") " + block.description
    }
}

extension ExprStmt: CustomStringConvertible {
    var description: String {
        return expr.description
    }
}

extension Block: CustomStringConvertible {
    var description: String {
        return "{\n\t" + stmts.map({ $0.description }).joined(separator: "\n\t") + "\n}"
    }
}

extension Return: CustomStringConvertible {
    var description: String {
        return "return " + expr.description
    }
}

extension Assign: CustomStringConvertible {
    var description: String {
        return lhs.description + " = " + rhs.description
    }
}

extension Decl: CustomStringConvertible {
    var description: String {
        return entity.description + (entity.constant ? " :: " : " := ") + rhs.description
    }
}
