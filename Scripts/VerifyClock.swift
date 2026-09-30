import AppKit
import ScreenSaver

/// Integration diagnostic: exercise the actual bundle with real elapsed time.
/// Reflection is confined to this diagnostic; production exposes no test hooks.
@main
struct VerifyClock {
    @MainActor static func main() throws {
        let bundle = Bundle(path: CommandLine.arguments[1])!
        guard let type = bundle.principalClass as? ScreenSaverView.Type,
              let view = type.init(frame: NSRect(x: 0, y: 0, width: 1440, height: 900), isPreview: false)
        else { fatalError("Cannot load screensaver principal class") }
        func field(_ value: Any, _ name: String) -> Any? {
            Mirror(reflecting: value).children.first { $0.label == name }?.value
        }
        view.startAnimation()
        let started = ProcessInfo.processInfo.systemUptime
        var holdStarted: Double?
        var previousPhase = ""
        var sawLife = false
        while ProcessInfo.processInfo.systemUptime - started < 23 {
            view.animateOneFrame()
            let now = ProcessInfo.processInfo.systemUptime
            let cycle = Mirror(reflecting: field(view, "cycle")!).children.first!.value
            let phase = String(describing: field(cycle, "phase")!)
            if phase != previousPhase {
                print(String(format: "%.2f s: %@", now - started, phase))
                previousPhase = phase
                if phase == "holding" { holdStarted = now }
                if phase == "releasing" || phase == "evolving" {
                    guard let holdStarted, now - holdStarted >= 19.95 else {
                        fatalError("Life started before 20 seconds of clock display")
                    }
                }
            }
            if phase == "evolving" { sawLife = true }
            Thread.sleep(forTimeInterval: 1 / 60)
        }
        view.stopAnimation()
        guard sawLife else { fatalError("Life did not begin after the clock display") }
        print("PASS: real bundle held the clock for 20 seconds before Life")
    }
}
