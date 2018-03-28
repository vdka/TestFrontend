

// This is a dummy value
var currentThreadId: ThreadId = 0

var checkerError: Bool = false

struct Checker {
    var topLevelScope: Scope

    /// - Returns: Was the stmt resolved if constant?
    func check(topLevelStmt: TopLevelStmt) -> Bool {
        let context = Context(scope: topLevelScope)
        check(stmt: topLevelStmt, context: context)
        print("Running check for \(topLevelStmt)")
        return context.unresolved
    }

    func check(stmt: Stmt, context: Context) {
        switch stmt {
        case let decl as Decl:
            check(expr: decl.rhs, context: context)

            if decl.entity.constant && !context.lastExprWasConstant && !context.unresolved {
                print("Expected constant declaration at \(decl.rhs.beg)")
                context.invalid = true
            }

            if context.scope === topLevelScope && decl.entity.name == "main" {
                context.entryPoint = decl.entity
            }

        case let assign as Assign:
            guard let entity = context.lookup(name: assign.lhs.name) else {
                print("Use of unresolved identifier \(assign.lhs) at \(assign.beg)")
                context.invalid = true
                return
            }
            if entity.constant {
                print("Cannot assign to constant value '\(entity)' at \(assign.beg)")
                print("  Declaration of \(entity) here \(entity.ident.beg)")
                context.invalid = true
                return
            }

            check(expr: assign.lhs, context: context)
            check(expr: assign.rhs, context: context)
            if let entity = assign.lhs.entity, entity.constant, !context.lastExprWasConstant {
                print("Cannot assign to constant value \(assign.lhs) at \(assign.beg)")
            }

        case let block as Block:
            let bContext = Context(parent: context, scope: block.scope)
            for stmt in block.stmts {
                check(stmt: stmt, context: bContext)
            }

        case let stmt as ExprStmt:
            check(expr: stmt.expr, context: context)

        case let ret as Return:
            check(expr: ret.expr, context: context)

        default:
            fatalError("Wasn't expecting \(type(of: stmt)) to be a top level stmt")
        }
    }

    func check(expr: Expr, context: Context) {
        switch expr {
        case let lit as Literal:
            lit.value = Double(lit.text)!
            context.lastExprWasConstant = true

        case let expr as Ident:
            guard let target = context.lookup(name: expr.name) else {
                print("Use of undeclared entity \(expr.name) at \(expr.beg)")
                context.invalid = true
                return
            }
            expr.entity = target
            context.lastExprWasConstant = target.constant
            if target.constant {
                switch target.state {
                case .unchecked:
                    // Suspend job until the target is checked
                    context.unresolved = true
                case .checking(let threadId):
                    if threadId == currentThreadId {
                        print("Cyclic dependency detected for \(expr) on \(target) at \(expr.beg)")
                        context.invalid = true
                    }
                case .emitting:
                    // Suspend job until the other is done
                    context.unresolved = true
                case .emitted:
                    // We have a constant value use it
                    break
                }
            }

        case let unary as Unary:
            check(expr: unary.expr, context: context)

        case let binary as Binary:
            check(expr: binary.lhs, context: context)
            let constantLHS = context.lastExprWasConstant
            check(expr: binary.rhs, context: context)
            context.lastExprWasConstant = context.lastExprWasConstant && constantLHS

        case let ternary as Ternary:
            check(expr: ternary.cond, context: context)
            var constant = context.lastExprWasConstant
            check(expr: ternary.a, context: context)
            constant = constant && context.lastExprWasConstant
            check(expr: ternary.b, context: context)
            constant = constant && context.lastExprWasConstant

        case let paren as Paren:
            check(expr: paren.expr, context: context)

        case let fn as Function:
            let fnContext = Context(parent: context, scope: fn.block.scope)
            for arg in fn.args {
                let entity = Entity(ident: arg, constant: false)
                arg.entity = entity
                fnContext.declare(entity: entity)
            }

            for stmt in fn.block.stmts {
                check(stmt: stmt, context: fnContext)
            }

            // There are no branches just check the last stmt for being a return
            if !(fn.block.stmts.last is Return) {
                print("No return in function at \(fn.beg)")
                context.invalid = true
            }

            context.lastExprWasConstant = true

        default:
            fatalError("Wasn't expecting \(type(of: expr)) to be an Expr")
        }
    }

    class Context {
        weak var parent: Context?
        var scope: Scope

        var invalid: Bool = false
        var unresolved: Bool = false

        var functionScope: Bool = false
        var lastExprWasConstant: Bool = false
        var entryPoint: Entity?

        init(parent: Context? = nil, scope: Scope) {
            self.parent = parent
            self.scope = scope
        }

        func lookup(name: String) -> Entity? {
            return scope.lookup(name: name)
        }

        func declare(entity: Entity) {
            let previous = scope.declare(entity: entity)
            if let previous = previous {
                print("Duplicate declaration of \(entity.name) at \(entity.ident.beg)")
                print("  Previous declaration was here \(previous.ident.beg)")
                invalid = true
            }

            if !functionScope && entity.name == "main" {
                print("Found main at \(entity.ident.beg)")
                entryPoint = entity
            }
        }
    }
}
