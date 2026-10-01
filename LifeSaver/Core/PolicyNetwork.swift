import Foundation

/// 3×3 convolutions: 3 → 16 → 16 → 16, followed by a 1×1 placement head.
/// SIMD packs output channels; inference needs no ML runtime or external model.
struct PolicyNetwork: Codable, Sendable, Equatable {
    static let parameterCount = 5_105
    let weights: [Float]

    init(random: inout SeededRandom) {
        weights = (0..<Self.parameterCount).map { index in
            // Modest symmetric initialization; zero biases.
            if (432..<448).contains(index) || (2752..<2768).contains(index) || (5072..<5088).contains(index) || index == 5104 { return 0 }
            return random.signed() * 0.18
        }
    }
    init(weights: [Float]) { self.weights = weights }
    var isValid: Bool { weights.count == Self.parameterCount && weights.allSatisfy { $0.isFinite && abs($0) <= 8 } }

    func mutated(random: inout SeededRandom, strength: Float = 0.08) -> PolicyNetwork {
        PolicyNetwork(weights: weights.map { weight in
            guard random.unit() < 0.12 else { return weight }
            return min(8, max(-8, weight + random.signed() * strength))
        })
    }

    func scores(board: Arena, player: Player) -> [Float] {
        let width = Arena.width, height = Arena.height
        var offset = 0
        func vector() -> SIMD16<Float> {
            defer { offset += 16 }
            return SIMD16<Float>(weights[offset..<offset + 16])
        }
        let first = (0..<27).map { _ in vector() }
        let firstBias = vector()
        var features = [SIMD16<Float>](repeating: .zero, count: board.cells.count)
        for y in 0..<height {
            for x in 0..<width {
                var sum = firstBias
                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let nx = x + kx - 1, ny = y + ky - 1
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let cell = board.cells[ny * width + nx]
                        let kernel = (ky * 3 + kx) * 3
                        sum += first[kernel + 2] // valid board positions; padding is zero
                        if cell == player.rawValue { sum += first[kernel] }
                        if cell == player.opponent.rawValue { sum += first[kernel + 1] }
                    }
                }
                features[y * width + x] = sum.replacing(with: SIMD16<Float>.zero, where: sum .< SIMD16<Float>.zero)
            }
        }
        for _ in 0..<2 {
            let kernel = (0..<144).map { _ in vector() }
            let bias = vector()
            var next = [SIMD16<Float>](repeating: .zero, count: features.count)
            for y in 0..<height {
                for x in 0..<width {
                    var sum = bias
                    for ky in 0..<3 {
                        for kx in 0..<3 {
                            let nx = x + kx - 1, ny = y + ky - 1
                            guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                            let input = features[ny * width + nx]
                            let start = (ky * 3 + kx) * 16
                            for channel in 0..<16 { sum += kernel[start + channel] * input[channel] }
                        }
                    }
                    next[y * width + x] = sum.replacing(with: SIMD16<Float>.zero, where: sum .< SIMD16<Float>.zero)
                }
            }
            features = next
        }
        let head = vector(), bias = weights[offset]
        return features.map { ($0 * head).sum() + bias }
    }

    func placements(board: Arena, player: Player, budget: Int = 3) -> [Int] {
        var legal = Set(board.legalPlacements(for: player))
        var imagined = board
        var chosen: [Int] = []
        for _ in 0..<budget {
            guard !legal.isEmpty else { break }
            let values = scores(board: imagined, player: player)
            // Stable tie-breaking makes evaluation reproducible.
            let best = legal.max { a, b in values[a] == values[b] ? a > b : values[a] < values[b] }!
            chosen.append(best)
            legal.remove(best)
            imagined.cells[best] = player.rawValue
        }
        return chosen
    }
}
