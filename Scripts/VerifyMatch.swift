import AppKit
import ScreenSaver

@main
struct VerifyMatch {
    @MainActor static func main() throws {
        let bundle = Bundle(path: CommandLine.arguments[1])!
        guard let type = bundle.principalClass as? ScreenSaverView.Type,
              let view = type.init(frame: NSRect(x: 0, y: 0, width: 1000, height: 800), isPreview: true)
        else { fatalError("Cannot load LifeSaver principal class") }
        func render() -> Data {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 800,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            view.draw(view.bounds)
            NSGraphicsContext.restoreGraphicsState()
            return Data(bytes: bitmap.bitmapData!, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        }
        view.startAnimation()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let first = render()
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        let second = render()
        precondition(zip(first, second).filter { $0 != $1 }.count > 500, "Match must visibly advance")
        precondition(view.hasConfigureSheet && view.configureSheet != nil, "Settings must load")
        view.stopAnimation()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        let stopped = render()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        precondition(render() == stopped, "Stopped session must stop changing")
        view.startAnimation()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        precondition(render() != stopped, "Session must restart")
        view.stopAnimation()
        print("PASS: LifeSaver loads, animates, opens settings, stops, and restarts")
    }
}
