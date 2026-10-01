import ScreenSaver

@MainActor
final class SettingsStore {
    private let defaults = ScreenSaverDefaults(forModuleWithName: "rybkr.LifeSaver")!
    func load() -> SaverSettings {
        defaults.register(defaults: ["speed": 12.0, "trainingEnabled": true])
        return SaverSettings(generationsPerSecond: defaults.double(forKey: "speed"),
                             trainingEnabled: defaults.bool(forKey: "trainingEnabled"))
    }
    func save(_ settings: SaverSettings) {
        defaults.set(settings.generationsPerSecond, forKey: "speed")
        defaults.set(settings.trainingEnabled, forKey: "trainingEnabled")
        defaults.synchronize()
    }
}
