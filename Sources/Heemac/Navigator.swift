import AppKit
import os

enum Direction: String {
    case left, right, up, down
}

enum Navigator {
    static let log = Logger(subsystem: Settings.domain, category: "navigator")

    /// Focuses the nearest visible window in `direction`. Returns false when
    /// there is nothing to move to.
    static func move(_ direction: Direction) -> Bool {
        guard AXIsProcessTrusted() else {
            log.error("no Accessibility permission")
            return false
        }
        if let pid = Focus.focusedPid(), Panes.move(direction, pid: pid) {
            log.info("\(direction.rawValue, privacy: .public): moved pane")
            return true
        }
        let windows = WindowList.visible(minVisibleFraction: Settings.minVisibleFraction)
        let (origin, current) = startingPoint(in: windows)
        guard let target = nearest(direction, from: origin, excluding: current, among: windows) else {
            log.info("\(direction.rawValue, privacy: .public): no window, from \(current?.app ?? "-", privacy: .public)")
            return false
        }
        log.info("\(direction.rawValue, privacy: .public): \(current?.app ?? "-", privacy: .public) -> \(target.app, privacy: .public)")
        Focus.focus(target)
        return true
    }

    /// The rectangle to navigate from, and the window it belongs to if that
    /// window is one of the candidates.
    static func startingPoint(in windows: [WindowInfo]) -> (CGRect, WindowInfo?) {
        if let focused = Focus.current() {
            if let id = focused.id, let w = windows.first(where: { $0.ids.contains(id) }) {
                return (w.frame, w)
            }
            if let frame = focused.frame {
                if let w = windows.first(where: { $0.pid == focused.pid && $0.frame.isRoughly(frame) }) {
                    return (w.frame, w)
                }
                return (frame, nil)
            }
            if let w = windows.first(where: { $0.pid == focused.pid }) {
                return (w.frame, w)
            }
        }
        let mouse = CGEvent(source: nil)?.location ?? .zero
        return (CGRect(origin: mouse, size: .zero), nil)
    }

    /// Windows sharing a row (for left/right) or column (for up/down) with the
    /// origin win over closer ones that don't; the screen edge is a dead end.
    static func nearest(_ direction: Direction, from origin: CGRect, excluding current: WindowInfo?,
                        among windows: [WindowInfo]) -> WindowInfo?
    {
        let o = CGPoint(x: origin.midX, y: origin.midY)
        var best: (window: WindowInfo, aligned: Bool, score: CGFloat)?

        for w in windows where w.ids != current?.ids {
            let c = w.center
            let primary: CGFloat
            let offset: CGFloat
            let aligned: Bool
            switch direction {
            case .left:
                primary = o.x - c.x; offset = abs(c.y - o.y)
                aligned = overlap(origin.minY, origin.maxY, w.frame.minY, w.frame.maxY)
            case .right:
                primary = c.x - o.x; offset = abs(c.y - o.y)
                aligned = overlap(origin.minY, origin.maxY, w.frame.minY, w.frame.maxY)
            case .up:
                primary = o.y - c.y; offset = abs(c.x - o.x)
                aligned = overlap(origin.minX, origin.maxX, w.frame.minX, w.frame.maxX)
            case .down:
                primary = c.y - o.y; offset = abs(c.x - o.x)
                aligned = overlap(origin.minX, origin.maxX, w.frame.minX, w.frame.maxX)
            }
            guard primary > 1 else { continue }
            let score = primary + 2 * offset
            if let b = best, (b.aligned && !aligned) || (b.aligned == aligned && b.score <= score) { continue }
            best = (w, aligned, score)
        }
        return best?.window
    }

    static func overlap(_ a0: CGFloat, _ a1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> Bool {
        min(a1, b1) - max(a0, b0) > 10
    }
}

enum Settings {
    static let domain = "io.github.raphaelluethy.heemac"
    /// The app's own defaults inside the bundle; the same domain when run unbundled
    /// (macOS rejects a suite named after the running app's own bundle identifier).
    /// UserDefaults is thread-safe.
    nonisolated(unsafe) static let defaults = Bundle.main.bundleIdentifier == domain
        ? .standard : UserDefaults(suiteName: domain) ?? .standard

    /// How much of a window must be visible for it to be a target (0...1).
    static var minVisibleFraction: Double {
        defaults.object(forKey: "minVisibleFraction") as? Double ?? 0.05
    }

    /// Move between panes of supported apps (Rex) before moving between windows.
    static var paneNavigation: Bool {
        defaults.object(forKey: "paneNavigation") as? Bool ?? true
    }
}
