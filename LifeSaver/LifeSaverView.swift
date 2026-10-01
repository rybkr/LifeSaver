import ScreenSaver

@objc(LifeSaverView)
final class LifeSaverView: ScreenSaverView {
    private let store = SettingsStore()
    private var settingsController: SettingsController?
    private var subscription: UUID?
    private var playing = false
    private var stoppedAt = ProcessInfo.processInfo.systemUptime

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1 / 60
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1 / 60
    }
    override var isOpaque: Bool { true }
    override var hasConfigureSheet: Bool { true }
    override var configureSheet: NSWindow? {
        settingsController = SettingsController(settings: store.load()) { [weak self] settings in
            self?.store.save(settings)
            SimulationSession.shared.configure(settings)
        }
        return settingsController?.window
    }
    override func startAnimation() {
        playing = true
        if subscription == nil {
            subscription = SimulationSession.shared.attach(preview: isPreview, settings: store.load())
        }
        super.startAnimation()
        needsDisplay = true
    }
    override func stopAnimation() {
        stoppedAt = ProcessInfo.processInfo.systemUptime
        playing = false
        if let subscription { SimulationSession.shared.detach(subscription) }
        subscription = nil
        super.stopAnimation()
    }
    override func animateOneFrame() { needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        SaverRenderer.draw(snapshot: SimulationSession.shared.snapshot, in: bounds,
                           now: playing ? ProcessInfo.processInfo.systemUptime : stoppedAt,
                           reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}
