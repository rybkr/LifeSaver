import Foundation

/// Presentation-only survival age. A new chip or ownership change starts bright.
struct CellAges: Sendable {
    private(set) var current = [UInt16](repeating: 0, count: Arena.width * Arena.height)
    private(set) var previous = [UInt16](repeating: 0, count: Arena.width * Arena.height)

    mutating func advance(from old: Arena, to new: Arena, reinforced: Set<Int> = []) {
        previous = current
        for index in new.cells.indices {
            if new.cells[index] != 0 && new.cells[index] == old.cells[index] && !reinforced.contains(index) {
                current[index] = min(1_024, current[index] + 1)
            } else { current[index] = 0 }
        }
    }

    /// Half the remaining distance to the 50% floor disappears every 24 generations.
    static func intensity(at age: UInt16) -> Double {
        0.5 + 0.5 * exp(-Double(age) * log(2) / 24)
    }
}
