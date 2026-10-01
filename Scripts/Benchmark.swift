import Foundation

@main
struct Benchmark {
    static func main() {
        var random = SeededRandom(state: 42)
        let network = PolicyNetwork(random: &random)
        let board = Arena.seeded(42)
        let started = ProcessInfo.processInfo.systemUptime
        var checksum: Float = 0
        for _ in 0..<20 { checksum += network.scores(board: board, player: .amber)[0] }
        let inference = (ProcessInfo.processInfo.systemUptime - started) / 20
        var evolution = Evolution(seed: 2026)
        let trainingStarted = ProcessInfo.processInfo.systemUptime
        var steps = 0
        repeat {
            evolution.advance()
            steps += 1
        } while ProcessInfo.processInfo.systemUptime - trainingStarted < 10
        let elapsed = ProcessInfo.processInfo.systemUptime - trainingStarted
        let perStep = elapsed / Double(steps)
        let projected = perStep * Double(Evolution.populationSize * Evolution.gamesPerCandidate * Match.generationLimit)
        print(String(format: "CNN: %d weights, %.1f KiB; %.3f ms/inference (checksum %.3f)",
                     PolicyNetwork.parameterCount, Double(PolicyNetwork.parameterCount * 4) / 1024, inference * 1000, checksum))
        print(String(format: "Training: %d advances / %.2f s; %d completed matches, %d selected generations", steps, elapsed, evolution.checkpoint.completedMatches, evolution.checkpoint.generation))
        print(String(format: "Approximate full evolutionary round: %.1f min active / %.1f min at 20%% duty", projected / 60, projected / 12))
        print("This measures throughput, not learning quality; early extinction can shorten rounds.")
    }
}
