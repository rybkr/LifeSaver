import AppKit

@MainActor
final class SettingsController: NSWindowController {
    private let speed: NSSlider
    private let training: NSButton
    private let value = NSTextField(labelWithString: "")
    private let onSave: (SaverSettings) -> Void

    init(settings: SaverSettings, onSave: @escaping (SaverSettings) -> Void) {
        self.onSave = onSave
        speed = NSSlider(value: settings.generationsPerSecond, minValue: 2, maxValue: 30, target: nil, action: nil)
        training = NSButton(checkboxWithTitle: "Evolve players in the background", target: nil, action: nil)
        training.state = settings.trainingEnabled ? .on : .off
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 232),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "LifeSaver Settings"
        super.init(window: window)
        let content = window.contentView!
        let title = NSTextField(labelWithString: "LifeSaver")
        title.font = .boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 24, y: 184, width: 400, height: 26)
        content.addSubview(title)
        let label = NSTextField(labelWithString: "Generations / second")
        label.frame = NSRect(x: 24, y: 141, width: 155, height: 22)
        content.addSubview(label)
        speed.frame = NSRect(x: 185, y: 141, width: 180, height: 24)
        speed.target = self
        speed.action = #selector(changed)
        speed.setAccessibilityLabel("Generations per second")
        content.addSubview(speed)
        value.frame = NSRect(x: 380, y: 141, width: 50, height: 22)
        content.addSubview(value)
        training.frame = NSRect(x: 24, y: 104, width: 405, height: 24)
        content.addSubview(training)
        let note = NSTextField(labelWithString: "Learning is saved between sessions. Preview does not train.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 24, y: 77, width: 420, height: 20)
        content.addSubview(note)
        for (title, action, x, key) in [("Cancel", #selector(cancel), 258.0, "\u{1b}"), ("Save", #selector(save), 350.0, "\r")] {
            let button = NSButton(title: title, target: self, action: action)
            button.keyEquivalent = key
            button.frame = NSRect(x: x, y: 20, width: 84, height: 32)
            content.addSubview(button)
        }
        changed()
    }
    required init?(coder: NSCoder) { nil }
    @objc private func changed() { value.stringValue = String(format: "%.0f", speed.doubleValue) }
    @objc private func save() {
        onSave(SaverSettings(generationsPerSecond: speed.doubleValue.rounded(), trainingEnabled: training.state == .on))
        cancel()
    }
    @objc private func cancel() {
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window) }
        window.orderOut(nil)
    }
}
