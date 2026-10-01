import AppKit
import ScreenSaver

// Load the built bundle exactly through its declared principal class, then
// exercise its lifecycle and render without installing it in System Settings.
@main
struct SmokeCheck {
    @MainActor static func main() throws {
        let path = CommandLine.arguments[1]
        let bundle = Bundle(path: path)!
        guard let type = bundle.principalClass as? ScreenSaverView.Type,
              let view = type.init(frame: NSRect(x: 0, y: 0, width: 1440, height: 900), isPreview: true)
        else { fatalError("Screensaver principal class could not be loaded") }
        view.startAnimation()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        view.animateOneFrame()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1440, pixelsHigh: 900,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/preview.png"))
        view.stopAnimation()
        print("Loaded principal class and rendered build/preview.png")
    }
}
