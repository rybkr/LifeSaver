import Foundation

/// Keeps every state in this run in a hash table. Canonical byte snapshots allow
/// exact equality checks after hashing, so collisions never cause false repeats.
struct RepeatDetector {
    private var history: Set<Data> = []
    private var storedBytes = 0
    private let byteLimit: Int
    private(set) var isFull = false

    init(initial: Set<Cell>, byteLimit: Int = 32 * 1024 * 1024) {
        self.byteLimit = byteLimit
        _ = observe(initial)
    }

    mutating func observe(_ cells: Set<Cell>) -> Bool {
        // Board coordinates are nonnegative. Sort packed coordinates so the
        // snapshot is independent of Set iteration order and allocation layout.
        let coordinates = cells.map { UInt64($0.x) << 32 | UInt64($0.y) }.sorted()
        let snapshot = coordinates.withUnsafeBytes { Data($0) }
        if history.contains(snapshot) { return true }
        let cost = snapshot.count + 128 // include a conservative per-entry allowance
        guard storedBytes + cost <= byteLimit else {
            isFull = true
            return false
        }
        history.insert(snapshot)
        storedBytes += cost
        return false
    }
}
