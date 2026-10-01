import Foundation

/// Visible match choreography. Training uses Match directly and never pays for
/// introductions or the winner's final, gradually disappearing Life generations.
struct MatchPlayback: Sendable {
    enum Phase { case introducing, playing, departing, empty }
    static let chipAnimation = 0.18
    static let emptyPause = 0.12
    private(set) var phase: Phase = .introducing
    private(set) var match: Match
    private(set) var board = Arena()
    private(set) var round = 1
    private var previous = Arena()
    private var ages = CellAges()
    private var random: SeededRandom
    private var introduction: [Int] = []
    private var introduced = 0
    private var birthTimes: [Double]?
    private var departedAt = 0.0
    private var nextUpdate = 0.0
    private var updatedAt = 0.0
    private var interval = 1.0 / 8
    private var placements: Set<Int> = []

    init(seed: UInt64, amber: PolicyNetwork, blue: PolicyNetwork, now: Double, board: Arena? = nil) {
        random = SeededRandom(state: seed ^ 0x706c61796261636b)
        match = Match(seed: seed, amber: amber, blue: blue, board: board)
        beginIntroduction(now: now)
    }

    /// A rising removal hazard, with a finite endpoint even for prolific patterns.
    static func removalProbability(elapsed: Double, interval: Double) -> Double {
        let elapsed = max(0, elapsed - 1) // allow the winner a moment to evolve freely
        if elapsed >= 6 { return 1 }
        return 1 - exp(-0.15 * elapsed * elapsed * interval)
    }

    mutating func advance(now: Double, generationsPerSecond: Double,
                          champion: PolicyNetwork, challenger: PolicyNetwork) {
        guard now >= nextUpdate else { return }
        interval = 1 / SaverSettings(generationsPerSecond: generationsPerSecond).generationsPerSecond
        switch phase {
        case .introducing:
            if introduced < introduction.count {
                let index = introduction[introduced]
                previous = board
                board.cells[index] = match.board.cells[index]
                birthTimes![index] = now
                introduced += 1
                updatedAt = now
                nextUpdate = now + (introduced == introduction.count ? Self.chipAnimation : interval / 4)
            } else {
                // Every seed cell is fully visible before either bot gets a turn.
                previous = board
                birthTimes = nil
                phase = .playing
                updatedAt = now
                nextUpdate = now + interval
            }
        case .playing:
            previous = board
            match.advance()
            board = match.board
            placements = match.lastPlacements
            ages.advance(from: previous, to: board, reinforced: placements)
            updatedAt = now
            nextUpdate = now + interval
            if match.finished {
                departedAt = now
                phase = board.cells.contains(where: { $0 != 0 }) ? .departing : .empty
                if phase == .empty { nextUpdate += Self.emptyPause }
            }
        case .departing:
            previous = board
            board.step()
            let probability = Self.removalProbability(elapsed: now - departedAt, interval: interval)
            for index in board.cells.indices where board.cells[index] != 0 {
                if random.unit() < Float(probability) { board.cells[index] = 0 }
            }
            // No further bot moves: the settled match result and fitness stay fixed.
            placements = []
            ages.advance(from: previous, to: board)
            updatedAt = now
            nextUpdate = now + interval
            if !board.cells.contains(where: { $0 != 0 }) {
                phase = .empty
                // Let the last cell's death animation finish before the new seeds.
                nextUpdate += Self.emptyPause
            }
        case .empty:
            round += 1
            let a = round.isMultiple(of: 2) ? challenger : champion
            let b = round.isMultiple(of: 2) ? champion : challenger
            match = Match(seed: random.next(), amber: a, blue: b)
            beginIntroduction(now: now)
        }
    }

    func snapshot() -> ArenaSnapshot {
        var result = ArenaSnapshot(board: board, previous: previous, placements: placements,
            generation: match.generation, round: round, averageAdvantage: match.averageAdvantage,
            finished: match.finished, winner: match.winner, evolution: 0, evaluated: 0,
            evaluationTotal: 128, trainedMatches: 0, trainingStatus: "", updatedAt: updatedAt)
        result.ages = ages
        result.generationInterval = interval
        result.birthTimes = birthTimes
        return result
    }

    private mutating func beginIntroduction(now: Double) {
        let a = match.board.cells.indices.filter { match.board.cells[$0] == 1 }.shuffled(using: &random)
        let b = match.board.cells.indices.filter { match.board.cells[$0] == 2 }.shuffled(using: &random)
        introduction = []
        // Alternate teams while revealing independently shuffled positions.
        for index in 0..<max(a.count, b.count) {
            if index < a.count { introduction.append(a[index]) }
            if index < b.count { introduction.append(b[index]) }
        }
        board = Arena()
        previous = board
        ages = CellAges()
        birthTimes = Array(repeating: -.infinity, count: board.cells.count)
        introduced = 0
        placements = []
        phase = .introducing
        updatedAt = now
        nextUpdate = now
    }
}
