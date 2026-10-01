import Foundation

struct Match: Sendable {
    static let generationLimit = 1_000
    static let moveInterval = 8
    private(set) var board: Arena
    private(set) var generation = 0
    private(set) var cumulativeDifference = 0
    private(set) var finished = false
    private(set) var lastPlacements: Set<Int> = []
    let amber: PolicyNetwork
    let blue: PolicyNetwork
    let limit: Int

    init(seed: UInt64, amber: PolicyNetwork, blue: PolicyNetwork, limit: Int = generationLimit, board: Arena? = nil) {
        self.board = board ?? .seeded(seed)
        self.amber = amber
        self.blue = blue
        self.limit = max(1, limit)
    }

    var averageAdvantage: Double { Double(cumulativeDifference) / Double(finished ? limit : max(1, generation)) }
    var winner: Player? {
        guard finished else { return nil }
        if board.population(.amber) == 0 && board.population(.blue) == 0 { return nil }
        if board.population(.amber) == 0 && board.population(.blue) > 0 { return .blue }
        if board.population(.blue) == 0 && board.population(.amber) > 0 { return .amber }
        return cumulativeDifference == 0 ? nil : (cumulativeDifference > 0 ? .amber : .blue)
    }

    mutating func advance() {
        guard !finished else { return }
        lastPlacements = []
        if generation.isMultiple(of: Self.moveInterval) {
            let a = amber.placements(board: board, player: .amber)
            let b = blue.placements(board: board, player: .blue)
            lastPlacements = board.reinforce(amber: a, blue: b)
        }
        board.step()
        generation += 1
        cumulativeDifference += board.difference
        if board.population(.amber) == 0 || board.population(.blue) == 0 {
            // Treat the terminal population as held through the rest of the match,
            // so every candidate is evaluated over the same time horizon.
            cumulativeDifference += board.difference * (limit - generation)
            finished = true
        } else if generation >= limit { finished = true }
    }
}

struct EvolutionCheckpoint: Codable, Sendable {
    static let version = 1
    var version = Self.version
    var generation: Int
    var completedMatches: Int
    var random: SeededRandom
    var population: [PolicyNetwork]
    var archive: [PolicyNetwork]
    var champion: PolicyNetwork
    var challenger: PolicyNetwork

    var isValid: Bool {
        version == Self.version && generation >= 0 && generation < 1_000_000_000 &&
        completedMatches >= 0 && completedMatches < 1_000_000_000_000 &&
        population.count == Evolution.populationSize && (1...4).contains(archive.count) &&
        (population + archive + [champion, challenger]).allSatisfy(\.isValid)
    }
}

/// One bounded simulation step at a time; the host controls CPU duty cycle.
struct Evolution: Sendable {
    static let populationSize = 32
    static let gamesPerCandidate = 4
    private(set) var checkpoint: EvolutionCheckpoint
    private(set) var candidate = 0
    private(set) var game = 0
    private(set) var match: Match?
    private var scores = [Double](repeating: 0, count: populationSize)
    private var roundSeeds: [UInt64] = []
    private var opponents: [PolicyNetwork] = []
    let matchLimit: Int

    init(seed: UInt64 = 0x4c69666553617665, checkpoint: EvolutionCheckpoint? = nil,
         matchLimit: Int = Match.generationLimit) {
        self.matchLimit = matchLimit
        if let checkpoint, checkpoint.isValid {
            self.checkpoint = checkpoint
        } else {
            var random = SeededRandom(state: seed)
            let population = (0..<Self.populationSize).map { _ in PolicyNetwork(random: &random) }
            self.checkpoint = EvolutionCheckpoint(generation: 0, completedMatches: 0, random: random,
                population: population, archive: [population[0]], champion: population[0], challenger: population[1])
        }
        beginRound()
    }

    var evaluatedThisRound: Int { candidate * Self.gamesPerCandidate + game }
    var evaluationsPerRound: Int { Self.populationSize * Self.gamesPerCandidate }

    private mutating func beginRound() {
        roundSeeds = [checkpoint.random.next(), checkpoint.random.next()]
        let historical = checkpoint.archive[checkpoint.random.index(checkpoint.archive.count)]
        opponents = [checkpoint.champion, historical]
        candidate = 0
        game = 0
        scores = Array(repeating: 0, count: Self.populationSize)
        match = nil
    }

    /// Returns true when a newly selected population is ready to checkpoint.
    @discardableResult mutating func advance() -> Bool {
        if match == nil {
            let contender = checkpoint.population[candidate]
            let opponent = opponents[game / 2]
            let swapped = game % 2 == 1
            match = Match(seed: roundSeeds[game / 2], amber: swapped ? opponent : contender,
                          blue: swapped ? contender : opponent, limit: matchLimit)
        }
        match!.advance()
        guard match!.finished else { return false }
        scores[candidate] += match!.averageAdvantage * (game % 2 == 0 ? 1 : -1)
        checkpoint.completedMatches += 1
        match = nil
        game += 1
        if game == Self.gamesPerCandidate { game = 0; candidate += 1 }
        guard candidate == Self.populationSize else { return false }
        let ranked = checkpoint.population.indices.sorted {
            scores[$0] == scores[$1] ? $0 < $1 : scores[$0] > scores[$1]
        }
        let elites = ranked.prefix(4).map { checkpoint.population[$0] }
        checkpoint.champion = elites[0]
        checkpoint.challenger = elites[1]
        checkpoint.archive.append(elites[0])
        checkpoint.archive = Array(checkpoint.archive.suffix(4))
        checkpoint.population = elites
        while checkpoint.population.count < Self.populationSize - 1 {
            let parent = elites[checkpoint.random.index(elites.count)]
            checkpoint.population.append(parent.mutated(random: &checkpoint.random))
        }
        checkpoint.population.append(PolicyNetwork(random: &checkpoint.random))
        checkpoint.generation += 1
        beginRound()
        return true
    }
}
