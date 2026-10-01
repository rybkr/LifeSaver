import AppKit

@MainActor
enum SaverRenderer {
    private struct Glass {
        let shadow: NSColor
        let depth: NSColor
        let body: NSColor
        let light: NSColor
        let glint: NSColor
    }

    private enum Palette {
        // In-gamut OKLCH ramps with matched lightness stops. The warm and cool
        // players have comparable visual weight; highlights retain their hue.
        static let amber = Glass(shadow: color(0x4A3308), depth: color(0xB48226),
            body: color(0xE1AD57), light: color(0xF0D3A8), glint: color(0xFBF4EA))
        static let blue = Glass(shadow: color(0x1D3B51), depth: color(0x5093C4),
            body: color(0x7CBFF2), light: color(0xBADDF8), glint: color(0xEEF6FD))
        static func color(_ rgb: Int) -> NSColor {
            NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                    green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
    }

    // Cache at the actual device-pixel size: no repeated scaling of a large sprite.
    // Keep a few sizes for full-screen and preview windows on different displays.
    private static var materials: [Int: (amber: CGImage, blue: CGImage)] = [:]

    private static func cells(pixels: Int) -> (amber: CGImage, blue: CGImage) {
        if let cached = materials[pixels] { return cached }
        let pair = (amber: makeCell(glass: Palette.amber, round: false, pixels: pixels),
                    blue: makeCell(glass: Palette.blue, round: true, pixels: pixels))
        if materials.count >= 4 { materials.removeAll(keepingCapacity: true) }
        materials[pixels] = pair
        return pair
    }

    static func draw(snapshot: ArenaSnapshot, in bounds: NSRect, now: Double, reduceMotion: Bool) {
        NSColor.black.setFill()
        bounds.fill()
        guard bounds.width > 0, bounds.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: bounds)
        context.interpolationQuality = .high
        // Only the cells are visible; equal margins center the invisible arena.
        let idealPitch = min(bounds.width * 0.86 / CGFloat(Arena.width), bounds.height * 0.86 / CGFloat(Arena.height))
        let backingScale = max(0.01, hypot(context.ctm.a, context.ctm.b))
        let pixels = max(1, Int(floor(idealPitch * backingScale)))
        let pitch = CGFloat(pixels) / backingScale
        let centered = CGPoint(x: bounds.midX - CGFloat(Arena.width) * pitch / 2,
                               y: bounds.midY - CGFloat(Arena.height) * pitch / 2)
        let deviceOrigin = context.convertToDeviceSpace(centered)
        let origin = context.convertToUserSpace(CGPoint(x: deviceOrigin.x.rounded(), y: deviceOrigin.y.rounded()))
        let material = cells(pixels: pixels)
        let progress = reduceMotion ? 1 : min(1, max(0, (now - snapshot.updatedAt) / 0.08))
        for index in snapshot.board.cells.indices {
            let current = snapshot.board.cells[index], old = snapshot.previous.cells[index]
            let value = current == 0 ? old : current
            guard let player = Player(rawValue: value) else { continue }
            let opacity = current == 0 ? 0.25 * (1 - progress) : (old == current ? 1 : 0.8 + 0.2 * progress)
            guard opacity > 0 else { continue }
            let x = index % Arena.width, y = index / Arena.width
            context.setAlpha(opacity)
            context.draw(player == .amber ? material.amber : material.blue,
                in: CGRect(x: origin.x + CGFloat(x) * pitch,
                           y: origin.y + CGFloat(Arena.height - 1 - y) * pitch,
                           width: pitch, height: pitch))
        }
    }

    private static func makeCell(glass: Glass, round: Bool, pixels: Int) -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: CGFloat(pixels) / 96, y: CGFloat(pixels) / 96)
        let devicePixel = 96 / CGFloat(pixels)
        // Snap the silhouette as well as the sprite to physical pixel boundaries.
        let inset = max(1, (CGFloat(pixels) / 12).rounded()) * devicePixel
        let rect = CGRect(x: inset, y: inset, width: 96 - 2 * inset, height: 96 - 2 * inset)
        let shape = round ? CGPath(ellipseIn: rect, transform: nil) :
            CGPath(roundedRect: rect, cornerWidth: 19, cornerHeight: 19, transform: nil)
        func gradient(_ colors: [NSColor], _ stops: [CGFloat]) -> CGGradient {
            CGGradient(colorsSpace: colorSpace, colors: colors.map(\.cgColor) as CFArray, locations: stops)!
        }
        context.addPath(shape)
        context.clip()
        // An opaque, luminous tint keeps the glass readable on pure black.
        // Optical depth comes from the color ramp, not a nearly invisible center.
        context.drawLinearGradient(gradient([
            glass.body, glass.depth, glass.body, glass.light
        ], [0, 0.26, 0.7, 1]),
            start: CGPoint(x: 62, y: 8), end: CGPoint(x: 34, y: 88),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        context.drawRadialGradient(gradient([
            glass.light.withAlphaComponent(0.28), glass.light.withAlphaComponent(0)
        ], [0, 1]), startCenter: CGPoint(x: 65, y: 10), startRadius: 0,
            endCenter: CGPoint(x: 65, y: 10), endRadius: 29, options: [])
        context.drawRadialGradient(gradient([
            glass.glint.withAlphaComponent(0.24), glass.glint.withAlphaComponent(0)
        ], [0, 1]), startCenter: CGPoint(x: 29, y: 88), startRadius: 0,
            endCenter: CGPoint(x: 29, y: 88), endRadius: 28, options: [])

        // One narrow continuous rim; broad translucent bevels softened the edge.
        context.saveGState()
        context.addPath(shape)
        context.setLineWidth(devicePixel * 2)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(gradient([
            glass.light.withAlphaComponent(0.68), glass.light.withAlphaComponent(0.38),
            glass.glint.withAlphaComponent(0.86)
        ], [0, 0.5, 1]), start: CGPoint(x: 70, y: 8), end: CGPoint(x: 26, y: 88),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()

        // Small upper reflection and lower caustic are clipped into the glass.
        let reflection = CGMutablePath()
        reflection.move(to: CGPoint(x: round ? 21 : 17, y: 68))
        reflection.addCurve(to: CGPoint(x: 58, y: 84),
                            control1: CGPoint(x: 25, y: 83), control2: CGPoint(x: 40, y: 88))
        context.addPath(reflection)
        context.setLineWidth(max(1.4, devicePixel * 0.7))
        context.setLineCap(.round)
        context.setStrokeColor(glass.glint.withAlphaComponent(0.85).cgColor)
        context.strokePath()
        return context.makeImage()!
    }
}
