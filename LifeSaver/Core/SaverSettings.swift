struct SaverSettings: Sendable, Equatable {
    var generationsPerSecond: Double
    var trainingEnabled: Bool
    init(generationsPerSecond: Double = 12, trainingEnabled: Bool = true) {
        self.generationsPerSecond = generationsPerSecond.isFinite ? min(30, max(2, generationsPerSecond)) : 12
        self.trainingEnabled = trainingEnabled
    }
}
