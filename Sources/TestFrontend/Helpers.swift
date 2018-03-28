
func canPack<T: FixedWidthInteger>(value: T, intoBits bits: Int) -> Bool {
    let highestBit = (T.bitWidth - value.leadingZeroBitCount)
    return highestBit <= bits
}

func assertCanPack<T: FixedWidthInteger>(value: T, intoBits bits: Int, file: StaticString = #file, line: UInt = #line) {
    if !canPack(value: value, intoBits: bits) {
        assertionFailure("Cannot store \(value) into \(bits) bits", file: file, line: line)
    }
}
