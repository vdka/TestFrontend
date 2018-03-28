
struct Parser {
    var scanner: Scanner

    var pos: Pos
    var tok: Token
    var lit: String

    var scope: Scope
    var toplevel: Bool = true
    var invalid: Bool = false

    init(data: UnsafeRawBufferPointer, toplevel: Bool = true) {
        self.scanner = Scanner(data: data, errorHandler: { msg, pos in print("ERROR: \(msg) at \(pos)") })

        (pos, tok, lit) = scanner.scan()

        scope = Scope(parent: nil)
        self.toplevel = toplevel
    }

    mutating func parseGeneratingJobs(in queue: WorkQueue) -> Bool {
        var checkingJobs: [CheckerJob] = []
        while tok != .eof {
            let stmt = parseTopLevelStmt()

            let checker = Checker(topLevelScope: scope)
            let work = CheckerJob(queue: queue, checker: checker, stmt: stmt)
            checkingJobs.append(work)
        }
        queue.work.append(contentsOf: checkingJobs as [WorkUnit])
        return invalid
    }

    mutating func parseEmittingNodes() -> [TopLevelStmt] {
        var stmts: [TopLevelStmt] = []
        while tok != .eof {
            let stmt = parseTopLevelStmt()
            stmts.append(stmt)
        }
        return stmts
    }

    mutating func parseBlock() -> Block {
        let beg = pos
        next()
        var stmts: [Stmt] = []
        while tok != .rbrace && tok != .eof {
            let stmt = parseStmt()
            stmts.append(stmt)
        }
        let (end, _) = require(.rbrace) // We throw away `ok` because we *must* be either at an rbrace or eof here. rbrace means success, eof means failure.
        return Block(beg: beg, stmts: stmts, scope: scope, end: end)
    }

    mutating func parseTopLevelStmt() -> TopLevelStmt {
        let stmt = parseStmt(topLevel: true)
        guard let tl = stmt as? TopLevelStmt else {
            reportError("Expected a top level statement", at: stmt.beg)
            return Invalid(beg: stmt.beg, text: scanner.textInRange(beg: stmt.beg, end: stmt.end), end: stmt.end)
        }
        return tl
    }

    mutating func parseStmt(topLevel: Bool = false) -> Stmt {
        self.toplevel = topLevel
        switch tok {
        case .ident, .int, .fn, .lparen,
             .add, .sub:
            let stmt = parseSimpleStmt()
            expectTerm()
            return stmt

        case .return:
            let beg = pos
            next()
            let expr = parseExpr()
            expectTerm()
            return Return(beg: beg, expr: expr)

        case .lbrace:
            return parseBlock()

        default:
            let beg = pos
            reportError("Expected stmt", at: pos)
            skipToNextStmt()
            return Invalid(beg: beg, text: scanner.textInRange(beg: beg, end: pos), end: pos)
        }
    }

    mutating func parseSimpleStmt() -> Stmt {
        let x = parseExpr()

        switch tok {
        case .assign:
            guard let name = x as? Ident else {
                reportError("Expected identifier", at: x.beg)
                skipToNextStmt()
                return Invalid(beg: x.beg, text: scanner.textInRange(beg: x.beg, end: pos), end: pos)
            }
            next()
            let rhs = parseExpr()
            return Assign(lhs: name, rhs: rhs)

        case .colon:
            guard let name = x as? Ident else {
                reportError("Expected identifier", at: x.beg)
                skipToNextStmt()
                return Invalid(beg: x.beg, text: scanner.textInRange(beg: x.beg, end: pos), end: pos)
            }
            next()
            var constant = false
            if tok == .colon {
                next()
                constant = true
            } else {
                expect(.assign)
            }
            let rhs = parseExpr()
            let decl = Decl(name: name, constant: constant, rhs: rhs)
            if toplevel {
                let previous = scope.declare(entity: decl.entity)
                if let previous = previous {
                    print("Duplicate declaration of \(name) at \(name.beg)")
                    print("  Previous declaration was here \(previous.ident.beg)")
                    invalid = true
                }
            }
            return decl

        default:
            return ExprStmt(expr: x)
        }
    }

    mutating func parseExpr() -> Expr {
        return parseBinaryExpr(precedence: 1)
    }

    mutating func parseBinaryExpr(precedence: Int) -> Expr {
        var lhs = parseUnaryExpr()

        while true {
            let oprec = tokenPrecedence()
            if oprec < precedence {
                return lhs
            }
            let op = tok
            let loc = pos
            next()
            if op == .question { // parse a ternary
                let a = parseExpr()
                let (_, ok) = require(.colon)
                if !ok {
                    return Invalid(beg: lhs.beg, text: scanner.textInRange(beg: lhs.beg, end: pos), end: pos)
                }
                let b = parseExpr()
                return Ternary(cond: lhs, a: a, b: b)
            }
            let rhs = parseBinaryExpr(precedence: oprec + 1)
            lhs = Binary(lhs: lhs, op: op, pos: loc, rhs: rhs)
        }
    }

    mutating func parseUnaryExpr() -> Expr {
        switch tok {
        case .add, .sub:
            let beg = pos
            let op = tok
            next()
            let expr = parseAtom()
            return Unary(beg: beg, op: op, expr: expr)

        default:
            return parseAtom()
        }
    }

    mutating func parseAtom() -> Expr {
        switch tok {
        case .ident:
            let val = Ident(beg: pos, name: lit)
            next()
            return val

        case .int, .float:
            let val = Literal(beg: pos, tok: tok, text: lit)
            next()
            return val

        case .lparen:
            let beg = pos
            next()
            let expr = parseExpr()
            let (end, ok) = require(.rparen)
            guard ok else {
                return Invalid(beg: beg, text: scanner.textInRange(beg: beg, end: end), end: end)
            }
            return Paren(beg: beg, expr: expr, end: end)

        case .fn:
            return parseFunction()

        default:
            reportError("Unexpected token '\(tok)'", at: pos)
            let beg = pos
            next()
            return Invalid(beg: beg, text: scanner.textInRange(beg: beg, end: pos), end: pos)
        }
    }

    mutating func parseFunction() -> Expr {
        let beg = pos
        next()
        expect(.lparen)
        var args: [Ident] = []
        while tok == .ident {
            let val = Ident(beg: pos, name: lit)
            next()
            if tok == .comma {
                next()
            }
            args.append(val)
        }
        expect(.rparen)
        if tok != .lbrace {
            reportError("Missing lbrace", at: pos)
            // Continue
        }
        let block = parseBlock()
        return Function(beg: beg, args: args, block: block)
    }

    mutating func next() {
        (pos, tok, lit) = scanner.scan()
    }

    mutating func require(_ req: Token) -> (Pos, ok: Bool) {
        if self.tok != req {
            invalid = true
            reportError("Missing '\(req)'", at: pos)
            var end = pos
            while true {
                if tok == .term {
                    end = pos
                    next()
                    break
                } else if tok == .eof {
                    end = pos
                    break
                }
                next()
            }
            return (end, ok: false)
        }
        next()
        return (pos, ok: true)
    }

    mutating func expect(_ tok: Token) {
        if self.tok != tok {
            invalid = true
            reportError("Missing '\(tok)'", at: pos)
            next()
            return
        }
        next()
    }

    mutating func expectTerm() {
        // NOTE: We don't set invalid but it is an error.
        if self.tok == .rbrace || self.tok == .rparen {
            // Terminators may be omitted before these tokens
            return
        }
        guard self.tok == .term else {
            reportError("Missing terminator", at: pos)
            return
        }
        next()
    }

    func reportError(_ message: String, at pos: Pos) {
        print(message, pos)
    }

    mutating func skipToNextStmt() {
        // skip until terminator else end of file
        while tok != .eof {
            if tok == .term {
                next()
                break
            }
            next()
        }
    }

    func tokenPrecedence() -> Int {
        switch tok {
        case .lor, .question: // question is ternary
            return 1
        case .land:
            return 2
        case .eql, .neq, .lss, .leq, .gtr, .geq:
            return 3
        case .add, .sub, .or, .xor:
            return 4
        case .mul, .quo, .rem, .shl, .shr, .and:
            return 5
        default:
            return 0
        }
    }
}
