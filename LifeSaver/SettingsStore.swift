import ScreenSaver

@MainActor
final class SettingsStore {
    private let defaults = ScreenSaverDefaults(forModuleWithName: "rybkr.LifeSaver")!
    func load() -> SaverSettings {
        defaults.register(defaults: ["speed": 8.0, "trainingEnabled": true])
        if !defaults.bool(forKey: "smoothPlaybackDefaultsApplied") {
            // Move the former 12-GPS default to 8; preserve other chosen speeds.
            if defaults.double(forKey: "speed") == 12 { defaults.set(8.0, forKey: "speed") }
            defaults.set(true, forKey: "smoothPlaybackDefaultsApplied")
        }
        return SaverSettings(generationsPerSecond: defaults.double(forKey: "speed"),
                             trainingEnabled: defaults.bool(forKey: "trainingEnabled"))
    }
    func save(_ settings: SaverSettings) {
        defaults.set(settings.generationsPerSecond, forKey: "speed")
        defaults.set(settings.trainingEnabled, forKey: "trainingEnabled")
        defaults.synchronize()
    }
}
