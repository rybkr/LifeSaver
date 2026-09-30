import Foundation

/// All motion is presentation-only; the Life seed is always the complete clock.
enum ClockPresentation {
    struct Layer {
        let cells: Set<Cell>
        var verticalScale: Double = 1
        var opacity: Double = 1
        var separation: Double = 0
        var offsetX: Double = 0
        var offsetY: Double = 0
        var clip: CellRect? = nil
    }

    static func layers(for cycle: SaverCycle, now: Double, reduceMotion: Bool) -> [Layer] {
        if reduceMotion {
            return [Layer(cells: cycle.board.cells, separation: cycle.phase == .evolving ? 1 : 0)]
        }
        switch cycle.phase {
        case .holding:
            return rollingDigits(for: cycle, now: now)
        case .releasing:
            return [Layer(cells: cycle.board.cells,
                          separation: eased((now - cycle.phaseStarted) / SaverCycle.releaseDuration))]
        case .building:
            return assemblingDigits(for: cycle, now: now)
        case .evolving:
            let progress = eased((now - cycle.lastGeneration) / min(0.08, 0.8 / cycle.settings.generationsPerSecond))
            if progress >= 1 { return [Layer(cells: cycle.board.cells, separation: 1)] }
            return [
                Layer(cells: cycle.board.cells.intersection(cycle.previousCells), separation: 1),
                Layer(cells: cycle.board.cells.subtracting(cycle.previousCells), opacity: progress, separation: 1),
                Layer(cells: cycle.previousCells.subtracting(cycle.board.cells), opacity: 1 - progress, separation: 1)
            ]
        }
    }

    private static func assemblingDigits(for cycle: SaverCycle, now: Double) -> [Layer] {
        let progress = (now - cycle.phaseStarted) / SaverCycle.buildDuration
        let digits = TimestampPattern.digits(timestamp: cycle.timestamp, columns: cycle.columns,
                                              rows: cycle.rows, margin: SaverCycle.margin)
        var layers = [Layer(cells: cycle.departingCells, opacity: 1 - eased(progress / 0.45), separation: 1)]
        for (index, digit) in digits.enumerated() {
            // Each horizontal strip arrives from alternating sides; a left-to-right
            // wave locks them into one solid numeral. No random flicker or noise.
            let strips = Dictionary(grouping: digit.cells, by: \.y)
            for (row, cells) in strips {
                let rowFraction = (Double(row) - digit.bounds.y) / digit.bounds.height
                let delay = 0.2 * Double(index) / Double(max(1, digits.count - 1)) + 0.12 * rowFraction
                let local = eased((progress - delay) / 0.68)
                let remaining = 1 - local
                let direction = row.isMultiple(of: 2) ? 1.0 : -1.0
                layers.append(Layer(cells: Set(cells), opacity: local,
                    separation: remaining,
                    offsetX: direction * digit.bounds.width * 0.45 * remaining,
                    offsetY: (rowFraction - 0.5) * digit.bounds.height * 0.9 * remaining))
            }
        }
        return layers
    }

    private static func rollingDigits(for cycle: SaverCycle, now: Double) -> [Layer] {
        let raw = (now - cycle.tickStarted) / SaverCycle.tickDuration
        guard raw >= 0, raw < 1 else { return [Layer(cells: cycle.board.cells)] }
        let current = TimestampPattern.digits(timestamp: cycle.timestamp, columns: cycle.columns,
                                               rows: cycle.rows, margin: SaverCycle.margin)
        let previous = TimestampPattern.digits(timestamp: cycle.previousTimestamp, columns: cycle.columns,
                                                rows: cycle.rows, margin: SaverCycle.margin)
        // A change in digit count or a wall-clock jump resolves directly.
        guard current.count == previous.count else { return [Layer(cells: cycle.board.cells)] }
        let progress = eased(raw)
        return zip(previous, current).flatMap { old, new -> [Layer] in
            guard old.value != new.value else { return [Layer(cells: new.cells)] }
            let travel = new.bounds.height + 1
            return [
                Layer(cells: old.cells, opacity: 1 - 0.35 * progress,
                      offsetY: travel * progress, clip: new.bounds),
                Layer(cells: new.cells, opacity: 0.65 + 0.35 * progress,
                      offsetY: -travel * (1 - progress), clip: new.bounds)
            ]
        }
    }

    private static func eased(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        return t * t * (3 - 2 * t)
    }
}
