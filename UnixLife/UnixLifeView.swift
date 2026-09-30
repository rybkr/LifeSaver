import ScreenSaver

@objc(UnixLifeView)
final class UnixLifeView: ScreenSaverView {
    private let store = SettingsStore()
    private var settings = SaverSettings()
    private var cycle: SaverCycle?
    private var settingsController: SettingsController?
    private var gridSize = NSSize.zero
    private var cellPitch: CGFloat = 6
    private var drawingTime: Double = 0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1 / 60
        settings = store.load()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1 / 60
        settings = store.load()
    }

    override var isOpaque: Bool { true }
    override var hasConfigureSheet: Bool { true }
    override var configureSheet: NSWindow? {
        settingsController = SettingsController(settings: store.load()) { [weak self] settings in
            guard let self else { return }
            self.store.save(settings)
            self.settings = settings
            self.cycle = nil
            self.needsDisplay = true
        }
        return settingsController?.window
    }

    override func startAnimation() {
        settings = store.load()
        cycle = nil
        super.startAnimation()
        animateOneFrame()
    }

    override func stopAnimation() {
        super.stopAnimation()
        cycle = nil
    }

    override func animateOneFrame() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        drawingTime = ProcessInfo.processInfo.systemUptime
        let unixTime = Int64(Date().timeIntervalSince1970)
        if cycle == nil || gridSize != bounds.size {
            gridSize = bounds.size
            // Scale the same composition down inside the system's small preview.
            let previewScale = isPreview ? bounds.width / 1440 : 1
            cellPitch = min(CGFloat(settings.cellSize) * previewScale,
                            bounds.width / 64, bounds.height / 16)
            cellPitch = max(0.1, cellPitch)
            cycle = SaverCycle(columns: Int(bounds.width / cellPitch),
                               rows: Int(bounds.height / cellPitch), settings: settings,
                               now: drawingTime, unixTime: unixTime)
        }
        cycle?.advance(now: drawingTime, unixTime: unixTime)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let cycle else {
            NSColor.black.setFill()
            bounds.fill()
            return
        }
        SaverRenderer.draw(cycle: cycle, in: bounds, cellPitch: cellPitch, now: drawingTime,
                           reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}
