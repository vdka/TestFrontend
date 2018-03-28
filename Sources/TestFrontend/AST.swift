
protocol Node: CustomStringConvertible {
    var beg: Pos { get }
    var end: Pos { get }
}

protocol Stmt: Node {}
protocol Expr: Node {}

protocol TopLevelStmt: Stmt {}

struct Invalid: Stmt, Expr, TopLevelStmt {
    var beg: Pos
    var text: String
    var end: Pos
}

struct Comment: Node {
    var beg: Pos
    var text: String
    var end: Pos { return beg + text.count }
}

class Ident: Expr {
    var beg: Pos
    var name: String
    var entity: Entity?
    var end: Pos { return beg + name.count }

    init(beg: Pos, name: String) {
        self.beg  = beg
        self.name = name
    }
}

class Literal: Expr {
    var beg: Pos
    var tok: Token
    var text: String
    var value: Double?
    var end: Pos { return beg + text.count }

    init(beg: Pos, tok: Token, text: String) {
        self.beg  = beg
        self.tok  = tok
        self.text = text
    }
}

class Unary: Expr {
    var beg: Pos
    var op: Token
    var expr: Expr
    var end: Pos { return expr.end }

    init(beg: Pos, op: Token, expr: Expr) {
        self.beg  = beg
        self.op  = op
        self.expr = expr
    }
}

class Binary: Expr {
    var lhs: Expr
    var op: Token
    var pos: Pos
    var rhs: Expr
    var beg: Pos { return lhs.beg }
    var end: Pos { return rhs.end }

    init(lhs: Expr, op: Token, pos: Pos, rhs: Expr) {
        self.lhs = lhs
        self.op  = op
        self.pos = pos
        self.rhs = rhs
    }
}

struct Ternary: Expr {
    var cond: Expr
    var a: Expr
    var b: Expr

    var beg: Pos { return cond.beg }
    var end: Pos { return b.end }

    init(cond: Expr, a: Expr, b: Expr) {
        self.cond = cond
        self.a = a
        self.b = b
    }
}

struct Paren: Expr {
    var beg: Pos
    var expr: Expr
    var end: Pos
}

struct Function: Expr {
    var beg: Pos
    var args: [Ident]
    var block: Block
    var end: Pos { return block.end }

    init(beg: Pos, args: [Ident], block: Block) {
        self.beg = beg
        self.args = args
        self.block = block
    }
}

struct ExprStmt: Expr, Stmt {
    var expr: Expr
    var beg: Pos { return expr.beg }
    var end: Pos { return expr.end }

    init(expr: Expr) {
        self.expr = expr
    }
}

struct Block: Stmt {
    var beg: Pos
    var stmts: [Stmt]
    var scope: Scope
    var end: Pos

    init(beg: Pos, stmts: [Stmt], scope: Scope, end: Pos) {
        self.beg = beg
        self.stmts = stmts
        self.scope = scope
        self.end = end
    }
}

struct Return: Stmt {
    var beg: Pos
    var expr: Expr
    var end: Pos { return expr.end }

    init(beg: Pos, expr: Expr) {
        self.beg = beg
        self.expr = expr
    }
}

struct Assign: Stmt {
    var lhs: Ident
    var rhs: Expr
    var beg: Pos { return lhs.beg }
    var end: Pos { return rhs.end }

    init(lhs: Ident, rhs: Expr) {
        self.lhs = lhs
        self.rhs = rhs
    }
}

struct Decl: Stmt, TopLevelStmt {
    var entity: Entity
    var rhs: Expr
    var beg: Pos { return entity.ident.beg }
    var end: Pos { return rhs.end }

    init(name: Ident, constant: Bool, rhs: Expr) {
        self.rhs = rhs
        self.entity = Entity(ident: name, constant: constant)
        entity.decl = self
    }
}
