import Foundation

struct SeededRandom: RandomNumberGenerator, Codable, Sendable {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
    mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
    mutating func index(_ count: Int) -> Int { Int(next() % UInt64(count)) }
    mutating func signed() -> Float { unit() * 2 - 1 }
}

enum Player: UInt8, Sendable {
    case amber = 1, blue = 2
    var opponent: Player { self == .amber ? .blue : .amber }
}

/// Finite two-color B3/S23 Life. Zero is empty; no wrapping or immortal cells.
struct Arena: Sendable, Equatable {
    static let width = 32
    static let height = 24
    var cells: [UInt8]

    init(cells: [UInt8] = Array(repeating: 0, count: width * height)) {
        precondition(cells.count == Self.width * Self.height && cells.allSatisfy { $0 <= 2 })
        self.cells = cells
    }

    static func seeded(_ seed: UInt64) -> Arena {
        var random = SeededRandom(state: seed)
        var board = Arena()
        // Mirrored colonies give both players identical starting resources.
        // A stable core prevents a random seed from dying before the first move.
        for y in 7..<17 {
            for x in 6..<14 where random.unit() < 0.33 || (x < 8 && y < 9) {
                board.cells[y * width + x] = Player.amber.rawValue
                board.cells[y * width + width - 1 - x] = Player.blue.rawValue
            }
        }
        return board
    }

    func population(_ player: Player) -> Int { cells.reduce(0) { $0 + ($1 == player.rawValue ? 1 : 0) } }
    var difference: Int { population(.amber) - population(.blue) }

    func legalPlacements(for player: Player) -> [Int] {
        cells.indices.filter { index in
            guard cells[index] == 0 else { return false }
            let x = index % Self.width, y = index / Self.width
            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0 && nx < Self.width && ny >= 0 && ny < Self.height,
                       cells[ny * Self.width + nx] == player.rawValue { return true }
                }
            }
            return false
        }
    }

    /// Validate against the same pre-move board. Contested placements cancel.
    @discardableResult mutating func reinforce(amber: [Int], blue: [Int], budget: Int = 3) -> Set<Int> {
        func validated(_ proposed: [Int], player: Player) -> Set<Int> {
            let legal = Set(legalPlacements(for: player))
            var accepted: Set<Int> = []
            for index in proposed where accepted.count < budget && legal.contains(index) { accepted.insert(index) }
            return accepted
        }
        let a = validated(amber, player: .amber), b = validated(blue, player: .blue)
        let conflict = a.intersection(b)
        for index in a.subtracting(conflict) { cells[index] = Player.amber.rawValue }
        for index in b.subtracting(conflict) { cells[index] = Player.blue.rawValue }
        return a.symmetricDifference(b)
    }

    mutating func step() {
        var total = [UInt8](repeating: 0, count: cells.count)
        var amber = total
        for index in cells.indices where cells[index] != 0 {
            let x = index % Self.width, y = index / Self.width
            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < Self.width, ny >= 0, ny < Self.height else { continue }
                    let neighbor = ny * Self.width + nx
                    total[neighbor] += 1
                    if cells[index] == Player.amber.rawValue { amber[neighbor] += 1 }
                }
            }
        }
        for index in cells.indices {
            if cells[index] == 0 {
                if total[index] == 3 { cells[index] = amber[index] >= 2 ? 1 : 2 }
            } else if total[index] != 2 && total[index] != 3 { cells[index] = 0 }
        }
    }
}
