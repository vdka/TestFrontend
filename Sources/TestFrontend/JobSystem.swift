
class WorkQueue {
    var parsingWork: [ParsingJob] = []
    var work: [WorkUnit] = []
}

protocol WorkUnit {
    var work: () -> Void { get }
}

struct ParsingJob {
    var parser: Parser
}

class CheckerJob: WorkUnit {
    unowned var queue: WorkQueue
    var checker: Checker
    var work: () -> Void = {}

    init(queue: WorkQueue, checker: Checker, stmt: TopLevelStmt) {
        self.queue = queue
        self.checker = checker
        self.work = {
            let unresolved = checker.check(topLevelStmt: stmt)
            if unresolved {
                queue.work.append(self)
            } else {
                let job = CodeGenJob(queue: queue, stmt: stmt)
                queue.work.append(job)
            }
        }
    }
}

class CodeGenJob: WorkUnit {
    unowned var queue: WorkQueue
    var work: () -> Void = {}

    init(queue: WorkQueue, stmt: TopLevelStmt) {
        self.queue = queue
        self.work = {
            print("Running emit for \(stmt)")

            switch stmt {
            case let decl as Decl:
                decl.entity.state = .emitted
            default:
                break
            }
        }
    }
}
