import AppKit
import CoreGraphics

/// One focus target. Windows of the same app stacked at exactly the same frame
/// (e.g. a terminal drawing an overlay window above its real one) are merged
/// into a single target, so they don't hide each other.
struct WindowInfo {
    var ids: [CGWindowID]
    let pid: pid_t
    let app: String
    let frame: CGRect
    let visibleFraction: Double
    /// Backed by a standard window or dialog (not a panel, popover or overlay).
    var isStandard = true

    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
}

extension CGRect {
    func isRoughly(_ other: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}

enum WindowList {
    static let excludedOwners: Set<String> = [
        "Window Server", "Dock", "Control Center", "Notification Center", "Raycast", "Heemac",
    ]
    static let minSize: CGFloat = 40
    static let samplesPerAxis = 16

    /// Normal windows on the current Spaces, front to back, that are at least
    /// `minVisibleFraction` visible (not covered by other windows).
    static func visible(minVisibleFraction: Double) -> [WindowInfo] {
        // Hidden windows are dropped before the per-app Accessibility queries,
        // the slowest part of a scan.
        markStandard(onScreen().filter { $0.visibleFraction >= minVisibleFraction }).filter(\.isStandard)
    }

    /// All candidate windows with their visible fraction, front to back.
    static func all() -> [WindowInfo] {
        markStandard(onScreen())
    }

    /// On-screen windows grouped by frame, with their visible fraction.
    private static func onScreen() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let screens = displayBounds()
        // One lookup per scan; creating an NSRunningApplication per window is far slower.
        let policies = Dictionary(NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0.activationPolicy) },
                                  uniquingKeysWith: { first, _ in first })
        var groups: [WindowInfo] = []

        for entry in raw {
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPid,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { continue }
            let owner = entry[kCGWindowOwnerName as String] as? String ?? "?"
            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.01, frame.width >= minSize, frame.height >= minSize,
                  !excludedOwners.contains(owner),
                  policies[pid] != .prohibited
            else { continue }

            if let i = groups.firstIndex(where: { $0.pid == pid && $0.frame.isRoughly(frame) }) {
                groups[i].ids.append(id)
                continue
            }
            let fraction = visibleFraction(of: frame, coveredBy: groups.map(\.frame), screens: screens)
            groups.append(WindowInfo(ids: [id], pid: pid, app: owner, frame: frame, visibleFraction: fraction))
        }
        return groups
    }

    /// Flags panels, popovers and overlays as non-standard. Without
    /// Accessibility access every window counts as standard.
    private static func markStandard(_ windows: [WindowInfo]) -> [WindowInfo] {
        guard AXIsProcessTrusted() else { return windows }
        var windows = windows
        var standardIDs: [pid_t: Set<CGWindowID>] = [:]
        for i in windows.indices {
            let pid = windows[i].pid
            if standardIDs[pid] == nil { standardIDs[pid] = standardWindowIDs(pid: pid) }
            windows[i].isStandard = !standardIDs[pid]!.isDisjoint(with: windows[i].ids)
        }
        return windows
    }

    static let standardSubroles: Set<String> = [kAXStandardWindowSubrole as String, kAXDialogSubrole as String]

    /// Window ids of the app's accessibility windows that are ordinary windows or dialogs.
    static func standardWindowIDs(pid: pid_t) -> Set<CGWindowID> {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        var ids = Set<CGWindowID>()
        for window in windows {
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
            if let subrole = subrole as? String, standardSubroles.contains(subrole), let id = Focus.windowID(window) {
                ids.insert(id)
            }
        }
        return ids
    }

    /// Share of the window's on-screen area not covered by windows above it,
    /// estimated on a sample grid.
    static func visibleFraction(of frame: CGRect, coveredBy above: [CGRect], screens: [CGRect]) -> Double {
        let above = above.filter { $0.intersects(frame) }
        var onScreen = 0
        var visible = 0
        let n = samplesPerAxis
        for ix in 0..<n {
            for iy in 0..<n {
                let p = CGPoint(
                    x: frame.minX + frame.width * (CGFloat(ix) + 0.5) / CGFloat(n),
                    y: frame.minY + frame.height * (CGFloat(iy) + 0.5) / CGFloat(n)
                )
                guard screens.contains(where: { $0.contains(p) }) else { continue }
                onScreen += 1
                if !above.contains(where: { $0.contains(p) }) { visible += 1 }
            }
        }
        return onScreen == 0 ? 0 : Double(visible) / Double(onScreen)
    }

    /// Display frames in global window-server coordinates (top-left origin).
    static func displayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
}
