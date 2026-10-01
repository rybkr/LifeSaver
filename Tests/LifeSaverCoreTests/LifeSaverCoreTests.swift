import Foundation
import Testing
@testable import LifeSaverCore

private func board(_ amber: [(Int, Int)], _ blue: [(Int, Int)] = []) -> Arena {
    var result = Arena()
    for (x, y) in amber { result.cells[y * Arena.width + x] = 1 }
    for (x, y) in blue { result.cells[y * Arena.width + x] = 2 }
    return result
}

@Test func lifeSurvivalAndMajorityBirth() {
    var arena = board([(4, 5), (5, 5)], [(6, 5)])
    arena.step()
    #expect(arena == board([(5, 4), (5, 5), (5, 6)]))
    var blueMajority = board([(4, 5)], [(5, 5), (6, 5)])
    blueMajority.step()
    #expect(blueMajority == board([], [(5, 4), (5, 5), (5, 6)]))
}

@Test func survivingCellsKeepTheirColorAndEdgesDoNotWrap() {
    var arena = board([(0, 0), (1, 0)], [(0, 1), (1, 1)])
    let original = arena
    arena.step()
    #expect(arena == original)
    #expect(arena.cells[Arena.width - 1] == 0)
    var isolated = board([(0, 0)], [(31, 23)])
    isolated.step()
    #expect(isolated.cells.allSatisfy { $0 == 0 })
}

@Test func reinforcementIsLegalBoundedAndSimultaneous() {
    var arena = board([(5, 5)], [(7, 5)])
    let contested = 5 * Arena.width + 6
    let legal = 4 * Arena.width + 5
    let accepted = arena.reinforce(amber: [contested, legal, legal, -1, 99999, 0], blue: [contested])
    #expect(accepted == [legal])
    #expect(arena.cells[contested] == 0)
    #expect(arena.population(.amber) == 2)
    let moves = arena.legalPlacements(for: .amber)
    arena.reinforce(amber: moves, blue: [])
    #expect(arena.population(.amber) == 5)
}

@Test func initialBoardIsSymmetricAndReproducible() {
    let arena = Arena.seeded(42)
    #expect(arena == Arena.seeded(42))
    #expect(arena.population(.amber) == arena.population(.blue))
    for y in 0..<Arena.height {
        for x in 0..<Arena.width where arena.cells[y * Arena.width + x] == 1 {
            #expect(arena.cells[(Arena.height - 1 - y) * Arena.width + Arena.width - 1 - x] == 2)
        }
    }
}

@Test func networkUsesOwnEnemyAndBoardChannels() {
    // Route only the center own-cell channel through channel zero of each layer.
    var weights = [Float](repeating: 0, count: PolicyNetwork.parameterCount)
    weights[(4 * 3) * 16] = 1
    weights[448 + (4 * 16) * 16] = 1
    weights[2768 + (4 * 16) * 16] = 1
    weights[5088] = 1
    let network = PolicyNetwork(weights: weights)
    let arena = board([(5, 5)], [(7, 5)])
    let a = network.scores(board: arena, player: .amber)
    let b = network.scores(board: arena, player: .blue)
    #expect(a[5 * Arena.width + 5] == 1)
    #expect(a[5 * Arena.width + 7] == 0)
    #expect(b[5 * Arena.width + 7] == 1)
    #expect(a.reduce(0, +) == 1)
}

@Test func networkOutputsLegalDistinctMovesAndMutations() {
    var random = SeededRandom(state: 42)
    let network = PolicyNetwork(random: &random)
    let arena = Arena.seeded(42)
    let moves = network.placements(board: arena, player: .amber)
    #expect(network.isValid)
    #expect(moves.count == 3 && Set(moves).count == 3)
    #expect(Set(moves).isSubset(of: Set(arena.legalPlacements(for: .amber))))
    let child = network.mutated(random: &random)
    #expect(child.isValid && child != network)
    #expect(network.placements(board: Arena(), player: .blue).isEmpty)
}

@Test func matchAccumulatesPopulationAdvantageAndStops() {
    var random = SeededRandom(state: 12)
    let network = PolicyNetwork(random: &random)
    var match = Match(seed: 123, amber: network, blue: network, limit: 4)
    var total = 0
    for _ in 0..<4 { match.advance(); total += match.board.difference }
    #expect(match.finished && match.generation == 4)
    #expect(match.cumulativeDifference == total)
    let final = match.board
    match.advance()
    #expect(match.board == final)
}

@Test func evolutionCompletesSelectionAndCheckpointRoundTrip() throws {
    var evolution = Evolution(seed: 23, matchLimit: 1)
    let initial = evolution.checkpoint.population
    for _ in 0..<Evolution.populationSize * Evolution.gamesPerCandidate { evolution.advance() }
    #expect(evolution.checkpoint.generation == 1)
    #expect(evolution.checkpoint.completedMatches == 128)
    #expect(evolution.checkpoint.isValid)
    #expect(initial.contains(evolution.checkpoint.champion))
    #expect(evolution.checkpoint.population != initial)
    let data = try PropertyListEncoder().encode(evolution.checkpoint)
    let decoded = try PropertyListDecoder().decode(EvolutionCheckpoint.self, from: data)
    let restored = Evolution(checkpoint: decoded)
    #expect(restored.checkpoint.champion == evolution.checkpoint.champion)
    #expect(restored.checkpoint.generation == 1)
}

@Test func corruptCheckpointAndInvalidPreferencesAreRejected() {
    var checkpoint = Evolution(seed: 8).checkpoint
    checkpoint.population[0] = PolicyNetwork(weights: [.nan])
    #expect(!checkpoint.isValid)
    #expect(Evolution(checkpoint: checkpoint).checkpoint.isValid)
    #expect(SaverSettings(generationsPerSecond: .nan).generationsPerSecond == 8)
    #expect(SaverSettings(generationsPerSecond: 100).generationsPerSecond == 30)
}

@Test func extinctionKeepsActualGenerationAndUsesFixedFitnessHorizon() {
    let zero = PolicyNetwork(weights: Array(repeating: 0, count: PolicyNetwork.parameterCount))
    var match = Match(seed: 0, amber: zero, blue: zero, limit: 100,
                      board: board([(5, 5), (6, 5), (5, 6), (6, 6)]))
    match.advance()
    #expect(match.finished)
    #expect(match.generation == 1)
    #expect(match.winner == .amber)
    #expect(match.averageAdvantage == Double(match.board.difference))
    var empty = Match(seed: 0, amber: zero, blue: zero, board: Arena())
    empty.advance()
    #expect(empty.finished && empty.winner == nil && empty.averageAdvantage == 0)
}

@Test func randomStartsHaveClearanceSeparationAndVaryAcrossTheBoard() {
    var left = false, right = false, above = false, below = false
    for seed in UInt64(0)..<64 {
        let arena = Arena.seeded(seed)
        let amber = arena.cells.indices.filter { arena.cells[$0] == 1 }
        let blue = arena.cells.indices.filter { arena.cells[$0] == 2 }
        #expect(amber.count == blue.count && amber.count >= 4)
        for index in amber + blue {
            #expect((2..<30).contains(index % Arena.width))
            #expect((2..<22).contains(index / Arena.width))
        }
        for a in amber {
            #expect(arena.cells[arena.cells.count - 1 - a] == 2)
            for b in blue {
                #expect(max(abs(a % Arena.width - b % Arena.width), abs(a / Arena.width - b / Arena.width)) >= 3)
            }
        }
        let x = Double(amber.reduce(0) { $0 + $1 % Arena.width }) / Double(amber.count)
        let y = Double(amber.reduce(0) { $0 + $1 / Arena.width }) / Double(amber.count)
        left = left || x < 10; right = right || x > 21
        above = above || y < 8; below = below || y > 15
    }
    #expect(left && right && above && below)
}

private let stationaryOpponents = board([(4,4), (5,4), (4,5), (5,5)], [(24,16), (25,16), (24,17), (25,17)])
private let zeroPolicy = PolicyNetwork(weights: Array(repeating: 0, count: PolicyNetwork.parameterCount))

@Test func visibleMatchesHaveNoGenerationDeadline() {
    var match = Match(seed: 0, amber: zeroPolicy, blue: zeroPolicy, board: stationaryOpponents)
    for _ in 0...Match.generationLimit { match.advance { _, _, _ in [] } }
    #expect(match.limit == nil && !match.finished && match.winner == nil)
    #expect(match.generation == Match.generationLimit + 1)
    #expect(match.board == stationaryOpponents)
    #expect(match.lastMoveWasEmergency)
}

@Test func stillLifeImmediatelyOffersOneChipToBothPlayers() {
    var match = Match(seed: 0, amber: zeroPolicy, blue: zeroPolicy, board: stationaryOpponents)
    var observations: [Arena] = []
    var players: [Player] = []
    match.advance { arena, player, budget in
        if budget == 3 { return [] }
        #expect(budget == 1)
        observations.append(arena)
        players.append(player)
        // Even an invalid over-budget answer can only place one chip.
        return Array(arena.legalPlacements(for: player).prefix(2))
    }
    #expect(match.generation == 1 && match.lastMoveWasEmergency)
    #expect(observations == [stationaryOpponents, stationaryOpponents])
    #expect(players == [.amber, .blue])
    #expect(match.lastPlacements.count == 2)
    #expect(match.board.population(.amber) == 5 && match.board.population(.blue) == 5)
}

@Test func periodTwoOscillatorTriggersBeforeRegularTurn() {
    let initial = board([(4,4), (5,4), (6,4)], [(24,16), (25,16), (26,16)])
    var match = Match(seed: 0, amber: zeroPolicy, blue: zeroPolicy, board: initial)
    match.advance { _, _, _ in [] }
    #expect(!match.lastMoveWasEmergency)
    var emergencies = 0
    match.advance { arena, player, budget in
        #expect(budget == 1)
        #expect(arena == initial)
        emergencies += 1
        return Array(arena.legalPlacements(for: player).prefix(1))
    }
    #expect(match.generation == 2 && match.lastMoveWasEmergency && emergencies == 2)
}

@Test func repeatDetectionIncludesOwnershipAndEvictsOldStates() {
    let a = board([(2,2)]), b = board([], [(2,2)]), c = board([(3,3)])
    var history = BoardHistory(capacity: 2)
    let firstA = history.observe(a)
    let firstB = history.observe(b)
    let repeatedA = history.observe(a)
    let firstC = history.observe(c)
    let evictedA = history.observe(a)
    #expect(!firstA && !firstB && repeatedA && !firstC && !evictedA)
    history.reset(to: b)
    let repeatedB = history.observe(b)
    let resetA = history.observe(a)
    #expect(repeatedB && !resetA)
}

@Test func extinctionEndsUnboundedMatchWithoutAnEmergencyMove() {
    var match = Match(seed: 0, amber: zeroPolicy, blue: zeroPolicy,
        board: board([(4,4), (5,4), (4,5), (5,5)], [(24,16)]))
    match.advance { _, _, _ in [] }
    #expect(match.finished && match.winner == .amber && !match.lastMoveWasEmergency)
    #expect(match.generation == 1 && match.averageAdvantage == 4)
}

@Test func presentationAgesOnlySurvivorsAndResetsNewChips() {
    let initial = board([(4,4), (5,4)], [(12,12)])
    var ages = CellAges()
    for _ in 0..<24 { ages.advance(from: initial, to: initial) }
    let a = 4 * Arena.width + 4, b = 4 * Arena.width + 5, c = 12 * Arena.width + 12
    #expect(ages.current[a] == 24 && ages.previous[a] == 23)
    let changed = board([(4,4), (6,4)], [(5,4)])
    ages.advance(from: initial, to: changed, reinforced: [a])
    #expect(ages.current[a] == 0) // replaced chip
    #expect(ages.current[b] == 0) // ownership changed
    #expect(ages.current[c] == 0) // died
    #expect(ages.current[4 * Arena.width + 6] == 0) // newborn
    #expect(ages.previous[a] == 24)
    for _ in 0..<1_100 { ages.advance(from: changed, to: changed) }
    #expect(ages.current[a] == 1_024)
}

@Test func agingDecayHasHalfBrightnessFloor() {
    #expect(CellAges.intensity(at: 0) == 1)
    #expect(abs(CellAges.intensity(at: 24) - 0.75) < 0.0001)
    #expect(abs(CellAges.intensity(at: 72) - 0.5625) < 0.0001)
    #expect(CellAges.intensity(at: 1_024) >= 0.5)
    #expect(CellAges.intensity(at: 1_024) < 0.501)
}

@Test func birthDeathAndOwnershipTransitionsHaveContinuousEndpoints() {
    #expect(ArenaPresentation.layers(from: 0, to: 1, progress: 0).isEmpty)
    let birth = ArenaPresentation.layers(from: 0, to: 1, progress: 0.5)
    #expect(birth.count == 1 && birth[0].opacity == 0.5 && birth[0].scale < 1)
    let alive = ArenaPresentation.layers(from: 0, to: 1, progress: 1)
    #expect(alive[0].opacity == 1 && alive[0].scale == 1)
    let death = ArenaPresentation.layers(from: 1, to: 0, progress: 0)
    #expect(death[0].opacity == 1 && death[0].scale == 1)
    #expect(ArenaPresentation.layers(from: 1, to: 0, progress: 1).isEmpty)
    let change = ArenaPresentation.layers(from: 1, to: 2, progress: 0.5)
    #expect(change.map(\.player) == [.amber, .blue])
    #expect(change.map(\.departing) == [true, false])
    let survivor = ArenaPresentation.layers(from: 1, to: 1, progress: 0.5)
    #expect(survivor[0].scale == 1 && survivor[0].opacity == 1)
}

@Test func transitionFinishesBeforeNextGenerationAtEverySpeed() {
    for speed in [2.0, 8, 12, 30] {
        let interval = 1 / speed
        #expect(ArenaPresentation.progress(now: 0, updatedAt: 0, interval: interval, reduceMotion: false) == 0)
        #expect(ArenaPresentation.progress(now: interval, updatedAt: 0, interval: interval, reduceMotion: false) == 1)
    }
    #expect(ArenaPresentation.progress(now: 0, updatedAt: 0, interval: 1, reduceMotion: true) == 1)
}

@Test func introductionAddsChipsOneAtATimeBeforePlay() {
    var playback = MatchPlayback(seed: 42, amber: zeroPolicy, blue: zeroPolicy, now: 0)
    let target = playback.match.board
    #expect(playback.board.cells.allSatisfy { $0 == 0 })
    playback.advance(now: 0, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.board.population(.amber) == 1 && playback.board.population(.blue) == 0)
    playback.advance(now: 0.02, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.board.population(.amber) == 1 && playback.board.population(.blue) == 0)
    playback.advance(now: 0.03125, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.board.population(.amber) == 1 && playback.board.population(.blue) == 1)
    let starts = playback.snapshot().birthTimes!.filter(\.isFinite).sorted()
    #expect(starts == [0, 0.03125])
    var time = 0.03125
    while playback.phase == .introducing && time < 10 {
        let population = playback.board.population(.amber) + playback.board.population(.blue)
        time += 0.03125
        playback.advance(now: time, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
        let nextPopulation = playback.board.population(.amber) + playback.board.population(.blue)
        #expect((0...1).contains(nextPopulation - population))
        #expect(playback.match.generation == 0)
    }
    #expect(playback.phase == .playing && playback.board == target)
    #expect(playback.snapshot().birthTimes == nil)
}

private func winningPlayback() -> (MatchPlayback, Double) {
    var playback = MatchPlayback(seed: 1, amber: zeroPolicy, blue: zeroPolicy, now: 0,
        board: board([(4,4), (5,4), (4,5), (5,5), (12,12), (13,12), (12,13), (13,13)]))
    var time = 0.0
    while playback.phase != .departing && time < 5 {
        playback.advance(now: time, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
        time += 0.05
    }
    return (playback, time)
}

@Test func winnerKeepsEvolvingWithoutChangingTheMatchResult() {
    var (playback, time) = winningPlayback()
    #expect(playback.phase == .departing && playback.match.winner == .amber)
    let result = playback.match.board
    let score = playback.match.averageAdvantage
    var expected = playback.board
    expected.step()
    time += 0.15
    playback.advance(now: time, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.board == expected)
    #expect(playback.match.board == result && playback.match.averageAdvantage == score)
    #expect(playback.match.winner == .amber)
}

@Test func removalsAccelerateAndAlwaysReachFullProbability() {
    #expect(MatchPlayback.removalProbability(elapsed: 1, interval: 0.125) == 0)
    let early = MatchPlayback.removalProbability(elapsed: 2, interval: 0.125)
    let middle = MatchPlayback.removalProbability(elapsed: 4, interval: 0.125)
    let late = MatchPlayback.removalProbability(elapsed: 6, interval: 0.125)
    #expect(early > 0 && early < middle && middle < late && late < 1)
    #expect(MatchPlayback.removalProbability(elapsed: 7, interval: 0.125) == 1)
}

@Test func outroClearsAndFinishesAnimatingBeforeNextIntroduction() {
    var (playback, time) = winningPlayback()
    let finishedAt = time
    while playback.phase != .empty && time - finishedAt < 8 {
        time += 0.125
        playback.advance(now: time, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    }
    #expect(playback.phase == .empty && playback.board.cells.allSatisfy { $0 == 0 })
    playback.advance(now: time + 0.05, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.round == 1 && playback.phase == .empty)
    playback.advance(now: time + 0.3, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.round == 2 && playback.phase == .introducing)
    #expect(playback.board.cells.allSatisfy { $0 == 0 })
    #expect(playback.snapshot().previous.cells.allSatisfy { $0 == 0 })
    playback.advance(now: time + 0.31, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.board.population(.amber) + playback.board.population(.blue) == 1)
}

@Test func simultaneousExtinctionAlsoStartsAFreshRound() {
    var playback = MatchPlayback(seed: 0, amber: zeroPolicy, blue: zeroPolicy, now: 0, board: Arena())
    playback.advance(now: 0, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    playback.advance(now: 0.125, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.phase == .empty && playback.match.winner == nil)
    playback.advance(now: 0.5, generationsPerSecond: 8, champion: zeroPolicy, challenger: zeroPolicy)
    #expect(playback.round == 2 && playback.phase == .introducing)
}
