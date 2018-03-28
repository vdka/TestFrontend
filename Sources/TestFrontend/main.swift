
import Foundation

var str = """
foo :: 5.0
main :: fn() {
    return 5 + 8 + 9 - -6
}
bar :: 1234 + 389 + foo
"""
let buf = UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer.allocate(bytes: str.utf8.count, alignedTo: 1), count: str.utf8.count)
buf.copyBytes(from: str.utf8)
let codeBuffer = UnsafeRawBufferPointer(buf)

let queue = WorkQueue()

var parser = Parser(data: codeBuffer)
var err = parser.parseGeneratingJobs(in: queue)
buf.deallocate()
if err {
    print("Parsing failed")
    exit(1)
}

while !queue.work.isEmpty {
    let unit = queue.work.removeFirst()
    unit.work()
}
