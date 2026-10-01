import Foundation

/// Exact, color-aware states in a bounded rolling window. Hash collisions are
/// resolved by Data equality; the production window costs ~768 KiB of cell bytes.
struct BoardHistory: Sendable {
    private let capacity: Int
    private var states: Set<Data> = []
    private var ring: [Data] = []
    private var next = 0

    init(capacity: Int = 1_024) { self.capacity = max(1, capacity) }

    @discardableResult mutating func observe(_ board: Arena) -> Bool {
        let state = Data(board.cells)
        if states.contains(state) { return true }
        if ring.count == capacity {
            states.remove(ring[next])
            ring[next] = state
            next = (next + 1) % capacity
        } else { ring.append(state) }
        states.insert(state)
        return false
    }

    mutating func reset(to board: Arena) {
        states.removeAll(keepingCapacity: true)
        ring.removeAll(keepingCapacity: true)
        next = 0
        observe(board)
    }
}
