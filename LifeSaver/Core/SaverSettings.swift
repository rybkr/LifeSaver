struct SaverSettings: Sendable, Equatable {
    var generationsPerSecond: Double
    var trainingEnabled: Bool
    init(generationsPerSecond: Double = 8, trainingEnabled: Bool = true) {
        self.generationsPerSecond = generationsPerSecond.isFinite ? min(30, max(2, generationsPerSecond)) : 8
        self.trainingEnabled = trainingEnabled
    }
}
