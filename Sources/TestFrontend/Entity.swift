
typealias ThreadId = Int

class Entity: Expr {
    var beg: Pos { return ident.beg }

    var end: Pos { return ident.end }

    var ident: Ident
    var constant: Bool
    var state: State

    /// - NOTE: Only set for top level entities
    var decl: Decl?

    enum State {
        case unchecked
        case checking(ThreadId) /* ThreadID */
        case emitting
        case emitted
    }

    init(ident: Ident, constant: Bool) {
        self.ident = ident
        self.constant = constant
        self.state = .unchecked
    }

    var name: String { return ident.name }

    func getValue() -> Double {
        return 0.0
    }
}

extension Entity: Hashable {

    static func ==(lhs: Entity, rhs: Entity) -> Bool {
        return lhs === rhs
    }

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}
