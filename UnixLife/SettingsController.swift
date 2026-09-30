import AppKit

@MainActor
final class SettingsController: NSWindowController {
    private var sliders: [NSSlider] = []
    private var values: [NSTextField] = []
    private let onSave: (SaverSettings) -> Void

    init(settings: SaverSettings, onSave: @escaping (SaverSettings) -> Void) {
        self.onSave = onSave
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "UnixLife Settings"
        super.init(window: window)
        let content = window.contentView!
        let title = NSTextField(labelWithString: "UnixLife")
        title.font = .boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 24, y: 252, width: 400, height: 26)
        content.addSubview(title)
        let specs: [(String, Double, Double, Double)] = [
            ("Clock duration", settings.clockDuration, 0, 60),
            ("Generations / second", settings.generationsPerSecond, 1, 60),
            ("Evolution limit", settings.evolutionDuration, 1, 120),
            ("Cell size", settings.cellSize, 3, 16)
        ]
        for (index, spec) in specs.enumerated() {
            let y = CGFloat(207 - index * 42)
            let label = NSTextField(labelWithString: spec.0)
            label.frame = NSRect(x: 24, y: y, width: 152, height: 22)
            content.addSubview(label)
            let slider = NSSlider(value: spec.1, minValue: spec.2, maxValue: spec.3,
                                  target: self, action: #selector(changed))
            slider.frame = NSRect(x: 180, y: y, width: 180, height: 24)
            slider.setAccessibilityLabel(spec.0)
            content.addSubview(slider)
            sliders.append(slider)
            let value = NSTextField(labelWithString: "")
            value.frame = NSRect(x: 370, y: y, width: 70, height: 22)
            content.addSubview(value)
            values.append(value)
        }
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 258, y: 20, width: 84, height: 32)
        content.addSubview(cancel)
        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 350, y: 20, width: 84, height: 32)
        content.addSubview(save)
        changed()
    }

    required init?(coder: NSCoder) { nil }

    @objc private func changed() {
        values[0].stringValue = String(format: "%.0f s", sliders[0].doubleValue)
        values[1].stringValue = String(format: "%.0f", sliders[1].doubleValue)
        values[2].stringValue = String(format: "%.0f s", sliders[2].doubleValue)
        values[3].stringValue = String(format: "%.0f pt", sliders[3].doubleValue)
    }

    @objc private func save() {
        onSave(SaverSettings(clockDuration: sliders[0].doubleValue.rounded(),
                             generationsPerSecond: sliders[1].doubleValue.rounded(),
                             evolutionDuration: sliders[2].doubleValue.rounded(),
                             cellSize: sliders[3].doubleValue.rounded()))
        dismiss()
    }

    @objc private func cancel() { dismiss() }

    private func dismiss() {
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window) }
        else { NSApp.endSheet(window) }
        window.orderOut(nil)
    }
}
