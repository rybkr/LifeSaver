/// Owns the entire build → hold → release → evolve lifecycle. The caller supplies monotonic
/// time for animation and wall time solely for the displayed Unix timestamp.
struct SaverCycle {
    enum Phase { case building, holding, releasing, evolving }
    static let margin = 16
    static let buildDuration = 0.9
    static let tickDuration = 0.32
    static let releaseDuration = 0.7
    let columns: Int
    let rows: Int
    let settings: SaverSettings
    private(set) var board: LifeBoard
    private(set) var phase: Phase = .building
    private(set) var timestamp: Int64 = 0
    private(set) var previousTimestamp: Int64 = 0
    private(set) var tickStarted: Double = -.infinity
    private(set) var phaseStarted: Double = 0
    private(set) var lastGeneration: Double = 0
    private(set) var previousCells: Set<Cell> = []
    private(set) var departingCells: Set<Cell> = []
    private var detector: RepeatDetector

    init(columns: Int, rows: Int, settings: SaverSettings, now: Double, unixTime: Int64) {
        self.columns = max(64, columns)
        self.rows = max(16, rows)
        self.settings = settings
        board = LifeBoard(width: self.columns + 2 * Self.margin,
                          height: self.rows + 2 * Self.margin, cells: [])
        detector = RepeatDetector(initial: [])
        begin(now: now, unixTime: unixTime)
    }

    mutating func advance(now: Double, unixTime: Int64) {
        switch phase {
        case .building:
            if now - phaseStarted >= Self.buildDuration {
                phase = .holding
                phaseStarted = now
            }
        case .holding:
            if settings.clockDuration > 1, unixTime != timestamp {
                previousTimestamp = timestamp
                timestamp = unixTime
                tickStarted = now
                seed()
            }
            if now - phaseStarted >= settings.clockDuration,
               now - tickStarted >= Self.tickDuration {
                phase = .releasing
                phaseStarted = now
            }
        case .releasing:
            if now - phaseStarted >= Self.releaseDuration {
                phase = .evolving
                phaseStarted = now
                lastGeneration = now
                previousCells = board.cells
                detector = RepeatDetector(initial: board.cells)
            }
        case .evolving:
            if now - phaseStarted >= settings.evolutionDuration {
                begin(now: now, unixTime: unixTime)
                return
            }
            let interval = 1 / settings.generationsPerSecond
            // Bound catch-up work after a delayed callback or a sleeping display.
            var steps = 0
            while now - lastGeneration >= interval, steps < 4 {
                lastGeneration += interval
                steps += 1
                previousCells = board.cells
                board.step()
                let visible = board.cells.contains {
                    $0.x >= Self.margin && $0.x < columns + Self.margin &&
                    $0.y >= Self.margin && $0.y < rows + Self.margin
                }
                if !visible || detector.observe(board.cells) || detector.isFull {
                    begin(now: now, unixTime: unixTime)
                    return
                }
            }
            if steps == 4 { lastGeneration = now }
        }
    }

    private mutating func begin(now: Double, unixTime: Int64) {
        departingCells = board.cells
        previousCells = []
        phase = .building
        phaseStarted = now
        timestamp = unixTime
        previousTimestamp = unixTime
        tickStarted = -.infinity
        seed()
        detector = RepeatDetector(initial: board.cells)
    }

    private mutating func seed() {
        board = LifeBoard(width: columns + 2 * Self.margin, height: rows + 2 * Self.margin,
                          cells: TimestampPattern.cells(timestamp: timestamp, columns: columns,
                                                        rows: rows, margin: Self.margin))
    }
}
