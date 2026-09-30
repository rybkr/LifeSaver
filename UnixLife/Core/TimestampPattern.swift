struct CellRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

/// Open, monospaced 5×9 numerals. The same cells draw the clock and seed Life.
enum TimestampPattern {
    struct Digit {
        let value: Int
        let cells: Set<Cell>
        let bounds: CellRect
    }

    private static let glyphs = [
        ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
        ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        ["01110", "10001", "10001", "01111", "00001", "00001", "01110"]
    ]

    static func cells(timestamp: Int64, columns: Int, rows: Int, margin: Int) -> Set<Cell> {
        Set(digits(timestamp: timestamp, columns: columns, rows: rows, margin: margin).flatMap(\.cells))
    }

    static func digits(timestamp: Int64, columns: Int, rows: Int, margin: Int) -> [Digit] {
        let numbers = String(max(0, timestamp)).compactMap(\.wholeNumberValue)
        let glyphWidth = numbers.count * 6 - 1
        let scale = max(1, min(Int(Double(columns) * 0.55) / glyphWidth, rows / 18))
        let originX = margin + (columns - glyphWidth * scale) / 2
        let originY = margin + (rows - 9 * scale) / 2
        return numbers.enumerated().map { index, number in
            var cells: Set<Cell> = []
            let glyph = glyphs[number]
            let tallGlyph = Array(glyph[0...2]) + [glyph[2]] + Array(glyph[3...4]) + [glyph[4]] + Array(glyph[5...6])
            for (row, line) in tallGlyph.enumerated() {
                for (column, bit) in line.enumerated() where bit == "1" {
                    for y in 0..<scale {
                        for x in 0..<scale {
                            cells.insert(Cell(x: originX + (index * 6 + column) * scale + x,
                                              y: originY + (8 - row) * scale + y))
                        }
                    }
                }
            }
            return Digit(value: number, cells: cells,
                         bounds: CellRect(x: Double(originX + index * 6 * scale), y: Double(originY),
                                          width: Double(5 * scale), height: Double(9 * scale)))
        }
    }
}
