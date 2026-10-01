import Foundation

/// Presentation timing is independent of both Life and background training.
enum ArenaPresentation {
    struct CellLayer {
        let player: Player
        let opacity: Double
        let scale: Double
        let departing: Bool
    }

    static func eased(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    static func progress(now: Double, updatedAt: Double, interval: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 1 : eased((now - updatedAt) / max(0.001, interval * 0.9))
    }

    static func layers(from old: UInt8, to current: UInt8, progress: Double) -> [CellLayer] {
        if old == current {
            return Player(rawValue: current).map { [CellLayer(player: $0, opacity: 1, scale: 1, departing: false)] } ?? []
        }
        var result: [CellLayer] = []
        if let player = Player(rawValue: old), progress < 1 {
            result.append(CellLayer(player: player, opacity: 1 - progress, scale: 1 - 0.18 * progress, departing: true))
        }
        if let player = Player(rawValue: current), progress > 0 {
            result.append(CellLayer(player: player, opacity: progress, scale: 0.82 + 0.18 * progress, departing: false))
        }
        return result
    }
}
