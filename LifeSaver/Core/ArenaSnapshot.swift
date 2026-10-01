import Foundation

/// Value-only handoff from the simulation worker to the main-thread renderer.
struct ArenaSnapshot: Sendable {
    var board: Arena
    var previous: Arena
    var placements: Set<Int>
    var generation: Int
    var round: Int
    var averageAdvantage: Double
    var finished: Bool
    var winner: Player?
    var evolution: Int
    var evaluated: Int
    var evaluationTotal: Int
    var trainedMatches: Int
    var trainingStatus: String
    var updatedAt: Double

    static func initial() -> ArenaSnapshot {
        let board = Arena.seeded(2026)
        return ArenaSnapshot(board: board, previous: board, placements: [], generation: 0, round: 1,
            averageAdvantage: 0, finished: false, winner: nil, evolution: 0, evaluated: 0,
            evaluationTotal: 128, trainedMatches: 0, trainingStatus: "Starting players", updatedAt: 0)
    }
}
