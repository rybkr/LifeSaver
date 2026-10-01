import AppKit
import ImageIO
import UniformTypeIdentifiers

@main
struct RenderMotion {
    @MainActor static func main() throws {
        let width = 1000, height = 800, frames = 600
        let url = URL(fileURLWithPath: "build/lifesaver-motion.gif")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let evolution = Evolution(seed: 2026)
        var playback = MatchPlayback(seed: 2026, amber: evolution.checkpoint.champion,
                                     blue: evolution.checkpoint.challenger, now: 0)
        for frame in 0..<frames {
            try autoreleasepool {
                let now = Double(frame) / 30
                playback.advance(now: now, generationsPerSecond: 8, champion: evolution.checkpoint.champion,
                                 challenger: evolution.checkpoint.challenger)
                let snapshot = playback.snapshot()
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                SaverRenderer.draw(snapshot: snapshot, in: NSRect(x: 0, y: 0, width: width, height: height), now: now, reduceMotion: false)
                NSGraphicsContext.restoreGraphicsState()
                CGImageDestinationAddImage(destination, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 30]] as CFDictionary)
                if [45, 300, 599].contains(frame) {
                    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/lifesaver-\(frame).png"))
                }
            }
        }
        precondition(CGImageDestinationFinalize(destination))
        print("Rendered build/lifesaver-motion.gif and three review frames")
    }
}
