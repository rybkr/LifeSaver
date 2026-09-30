import AppKit

@MainActor
enum SaverRenderer {
    static func draw(cycle: SaverCycle, in bounds: NSRect, cellPitch: CGFloat,
                     now: Double, reduceMotion: Bool) {
        NSColor.black.setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(false)
        NSColor.white.setFill()
        let offsetX = (bounds.width - CGFloat(cycle.columns) * cellPitch) / 2
        let offsetY = (bounds.height - CGFloat(cycle.rows) * cellPitch) / 2
        let layers = ClockPresentation.layers(for: cycle, now: now, reduceMotion: reduceMotion)
        // Solid glyphs gently separate into cells at the transition to Life.
        let devicePixel = 1 / max(1, abs(context.ctm.a))
        let fullGap = min(cellPitch * 0.3, max(devicePixel, cellPitch * 0.14))
        for layer in layers where layer.opacity > 0.001 && !layer.cells.isEmpty {
            context.saveGState()
            if let clip = layer.clip {
                context.clip(to: CGRect(
                    x: offsetX + (clip.x - Double(SaverCycle.margin)) * cellPitch,
                    y: offsetY + (clip.y - Double(SaverCycle.margin)) * cellPitch,
                    width: clip.width * cellPitch, height: clip.height * cellPitch))
            }
            let gap = fullGap * layer.separation
            let path = NSBezierPath()
            let low = layer.cells.map(\.y).min() ?? 0
            let high = layer.cells.map(\.y).max() ?? 0
            let centerY = offsetY + (CGFloat(low + high + 1) / 2 - CGFloat(SaverCycle.margin)) * cellPitch
            for cell in layer.cells {
                let x = cell.x - SaverCycle.margin
                let y = cell.y - SaverCycle.margin
                guard x >= 0, x < cycle.columns, y >= 0, y < cycle.rows else { continue }
                let rawY = offsetY + (CGFloat(y) + layer.offsetY) * cellPitch + gap / 2
                path.appendRect(NSRect(
                    x: offsetX + (CGFloat(x) + layer.offsetX) * cellPitch + gap / 2,
                    y: centerY + (rawY - centerY) * layer.verticalScale,
                    width: cellPitch - gap,
                    height: (cellPitch - gap) * layer.verticalScale))
            }
            // Smooth subpixel transitions; steady clock glyphs remain crisp.
            context.setShouldAntialias(layer.separation > 0 || layer.verticalScale != 1 || layer.offsetX != 0 || layer.offsetY != 0)
            NSColor.white.withAlphaComponent(layer.opacity).setFill()
            path.fill()
            context.restoreGState()
        }
    }
}
