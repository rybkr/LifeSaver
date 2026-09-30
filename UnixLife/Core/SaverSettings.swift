struct SaverSettings: Equatable {
    var clockDuration: Double
    var generationsPerSecond: Double
    var evolutionDuration: Double
    var cellSize: Double

    init(clockDuration: Double = 20, generationsPerSecond: Double = 12,
         evolutionDuration: Double = 30, cellSize: Double = 6) {
        func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        self.clockDuration = clamp(clockDuration, 0...60, fallback: 20)
        self.generationsPerSecond = clamp(generationsPerSecond, 1...60, fallback: 12)
        self.evolutionDuration = clamp(evolutionDuration, 1...120, fallback: 30)
        self.cellSize = clamp(cellSize, 3...16, fallback: 6)
    }
}
