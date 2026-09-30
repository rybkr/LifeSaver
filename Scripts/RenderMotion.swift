import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Deterministic visual study using the same renderer as the installed saver.
@main
struct RenderMotion {
    @MainActor static func main() throws {
        let width = 960
        let height = 600
        let url = URL(fileURLWithPath: "build/clock-motion.gif")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 120, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var cycle = SaverCycle(columns: 240, rows: 150, settings: SaverSettings(), now: 0, unixTime: 1_800_000_009)
        for frame in 0..<120 {
            try autoreleasepool {
                let now = Double(frame) / 30
                cycle.advance(now: now, unixTime: 1_800_000_009 + Int64(max(0, now - 0.6)))
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                SaverRenderer.draw(cycle: cycle, in: NSRect(x: 0, y: 0, width: width, height: height),
                                   cellPitch: 4, now: now, reduceMotion: false)
                NSGraphicsContext.restoreGraphicsState()
                CGImageDestinationAddImage(destination, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 30]] as CFDictionary)
                if [12, 40, 52, 70].contains(frame) {
                    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/motion-\(frame).png"))
                }
            }
        }
        precondition(CGImageDestinationFinalize(destination))
        print("Rendered build/clock-motion.gif and four review frames")
    }
}
