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
            #expect(arena.cells[y * Arena.width + Arena.width - 1 - x] == 2)
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
    #expect(SaverSettings(generationsPerSecond: .nan).generationsPerSecond == 12)
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
