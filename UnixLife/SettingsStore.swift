import ScreenSaver

@MainActor
final class SettingsStore {
    private let defaults = ScreenSaverDefaults(forModuleWithName: "rybkr.UnixLife")!

    func load() -> SaverSettings {
        // New preference key gives existing installations the longer clock phase.
        defaults.register(defaults: ["clockDuration": 20.0, "speed": 12.0, "timeout": 30.0, "cellSize": 6.0])
        return SaverSettings(clockDuration: defaults.double(forKey: "clockDuration").rounded(),
                             generationsPerSecond: defaults.double(forKey: "speed"),
                             evolutionDuration: defaults.double(forKey: "timeout"),
                             cellSize: defaults.double(forKey: "cellSize"))
    }

    func save(_ settings: SaverSettings) {
        defaults.set(settings.clockDuration, forKey: "clockDuration")
        defaults.set(settings.generationsPerSecond, forKey: "speed")
        defaults.set(settings.evolutionDuration, forKey: "timeout")
        defaults.set(settings.cellSize, forKey: "cellSize")
        defaults.synchronize()
    }
}
