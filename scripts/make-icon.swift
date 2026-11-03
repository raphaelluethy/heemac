// Renders Resources/AppIcon.icns: the heemac mascot, a window with eyes
// glancing at its neighbour. Run with `make icon`.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func drawIcon(in ctx: CGContext, size: CGFloat) {
    let s = size / 1024
    ctx.scaleBy(x: s, y: s)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    // Background squircle with a warm gradient.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(colors: [color(0xFFB347), color(0xFF5E62), color(0xD6338A)])!.draw(in: tile, angle: -70)

    // The neighbour window it is looking at, peeking from behind.
    let back = NSBezierPath(roundedRect: NSRect(x: 560, y: 330, width: 300, height: 330), xRadius: 44, yRadius: 44)
    color(0xFFFFFF, 0.45).setFill()
    back.fill()

    // Main window with a soft shadow.
    let mainRect = NSRect(x: 170, y: 250, width: 520, height: 500)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x5A0A3C, 0.35)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    color(0xFFFFFF).setFill()
    NSBezierPath(roundedRect: mainRect, xRadius: 56, yRadius: 56).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Title bar with traffic lights.
    let bar = NSBezierPath()
    bar.move(to: NSPoint(x: mainRect.minX, y: 650))
    bar.line(to: NSPoint(x: mainRect.maxX, y: 650))
    bar.lineWidth = 8
    color(0xF1D9E4).setStroke()
    bar.stroke()
    for (i, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        color(UInt32(hex)).setFill()
        NSBezierPath(ovalIn: NSRect(x: 215 + CGFloat(i) * 52, y: 680, width: 34, height: 34)).fill()
    }

    // Eyes glancing right, toward the neighbour.
    for x in [330.0, 530.0] {
        let eye = NSRect(x: x - 78, y: 360, width: 156, height: 190)
        color(0xFFFFFF).setFill()
        let white = NSBezierPath(ovalIn: eye)
        white.fill()
        white.lineWidth = 14
        color(0x2B1B33).setStroke()
        white.stroke()
        color(0x2B1B33).setFill()
        NSBezierPath(ovalIn: NSRect(x: x + 2, y: 405, width: 72, height: 84)).fill()
        color(0xFFFFFF).setFill()
        NSBezierPath(ovalIn: NSRect(x: x + 40, y: 455, width: 22, height: 22)).fill()
    }

    // A little smile.
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 395, y: 315))
    smile.curve(to: NSPoint(x: 485, y: 315), controlPoint1: NSPoint(x: 420, y: 285), controlPoint2: NSPoint(x: 460, y: 285))
    smile.lineWidth = 14
    smile.lineCapStyle = .round
    color(0x2B1B33).setStroke()
    smile.stroke()
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        drawIcon(in: ctx, size: CGFloat(px))
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
print(iconset.path)
