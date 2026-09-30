struct Cell: Hashable, Sendable {
    let x: Int
    let y: Int
}

/// A finite B3/S23 world. Coordinates outside its bounds are always dead.
struct LifeBoard: Equatable {
    let width: Int
    let height: Int
    private(set) var cells: Set<Cell>

    init(width: Int, height: Int, cells: Set<Cell>) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.cells = cells.filter { $0.x >= 0 && $0.x < width && $0.y >= 0 && $0.y < height }
    }

    mutating func step() {
        var neighbors: [Cell: Int] = [:]
        neighbors.reserveCapacity(cells.count * 4)
        for cell in cells {
            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let candidate = Cell(x: cell.x + dx, y: cell.y + dy)
                    guard candidate.x >= 0, candidate.x < width,
                          candidate.y >= 0, candidate.y < height else { continue }
                    neighbors[candidate, default: 0] += 1
                }
            }
        }
        cells = Set(neighbors.compactMap { cell, count in
            count == 3 || (count == 2 && cells.contains(cell)) ? cell : nil
        })
    }
}

