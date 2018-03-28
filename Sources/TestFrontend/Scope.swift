
class Scope {
    weak var parent: Scope?
    var members: [String: Entity] = [:]

    init(parent: Scope?) {
        self.parent = parent
    }

    static let global = Scope(parent: nil)

    func lookup(name: String) -> Entity? {
        if let entity = members[name] {
            return entity
        }
        return parent?.lookup(name: name)
    }

    func declare(entity: Entity) -> Entity? {
        let previous = members[entity.name]
        members[entity.name] = entity
        return previous
    }
}
