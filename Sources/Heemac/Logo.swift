import AppKit

/// Where the menu bar mascot is looking.
enum Gaze {
    case center, blink
    case look(Direction)
}

/// The menu bar mascot: a window with two eyes that glance toward the window
/// focus just moved to, and blink when there was nowhere to go.
enum Logo {
    static func menuBarImage(_ gaze: Gaze) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let window = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 2.25, width: 14.5, height: 13.5),
                                      xRadius: 3.2, yRadius: 3.2)
            window.lineWidth = 1.5
            window.stroke()

            let titleBar = NSBezierPath()
            titleBar.move(to: NSPoint(x: 1.75, y: 12.4))
            titleBar.line(to: NSPoint(x: 16.25, y: 12.4))
            titleBar.lineWidth = 1.1
            titleBar.stroke()

            let (dx, dy) = offset(gaze)
            for x in [6.3, 11.7] {
                let center = NSPoint(x: x, y: 7.3)
                let eye = NSBezierPath(ovalIn: NSRect(x: center.x - 2.5, y: center.y - 2.6, width: 5, height: 5.2))
                eye.lineWidth = 1
                if case .blink = gaze {
                    let lid = NSBezierPath()
                    lid.move(to: NSPoint(x: center.x - 1.8, y: center.y))
                    lid.line(to: NSPoint(x: center.x + 1.8, y: center.y))
                    lid.lineWidth = 1.3
                    lid.lineCapStyle = .round
                    lid.stroke()
                } else {
                    eye.stroke()
                    NSBezierPath(ovalIn: NSRect(x: center.x + dx - 1.25, y: center.y + dy - 1.25,
                                                width: 2.5, height: 2.5)).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Heemac"
        return image
    }

    private static func offset(_ gaze: Gaze) -> (CGFloat, CGFloat) {
        guard case let .look(direction) = gaze else { return (0, 0) }
        switch direction {
        case .left: return (-1, 0)
        case .right: return (1, 0)
        case .up: return (0, 1.1)
        case .down: return (0, -1.1)
        }
    }
}
