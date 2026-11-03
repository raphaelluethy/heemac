import AppKit
import ApplicationServices

struct FocusedWindow {
    let pid: pid_t
    let id: CGWindowID?
    let frame: CGRect?
}

enum Focus {
    /// The window that currently has keyboard focus, as accessibility reports it.
    static func current() -> FocusedWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var appValue: CFTypeRef?
        var pid: pid_t = 0
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appValue) == .success,
           let appValue {
            AXUIElementGetPid(appValue as! AXUIElement, &pid)
        } else if let app = NSWorkspace.shared.frontmostApplication {
            pid = app.processIdentifier
        } else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(pid)
        var winValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winValue) == .success,
              let winValue
        else { return FocusedWindow(pid: pid, id: nil, frame: nil) }
        let window = winValue as! AXUIElement
        return FocusedWindow(pid: pid, id: windowID(window), frame: frame(window))
    }

    /// Raises `target`, activates its app and makes it the key window, retrying
    /// briefly when the app doesn't take focus on the first attempt.
    static func focus(_ target: WindowInfo, attempts: Int = 3) {
        let axWindow = axWindow(for: target)
        let wid = axWindow.flatMap(windowID) ?? target.ids[0]
        for attempt in 1...attempts {
            focusOnce(target, axWindow: axWindow, wid: wid)
            for _ in 0..<5 {
                usleep(20_000)
                if focusedPid() == target.pid { return }
            }
            Navigator.log.info("focus attempt \(attempt) on \(target.app, privacy: .public) did not stick")
        }
    }

    static func focusedPid() -> pid_t? {
        var appValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString,
                                            &appValue) == .success, let appValue
        else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(appValue as! AXUIElement, &pid)
        return pid
    }

    private static func focusOnce(_ target: WindowInfo, axWindow: AXUIElement?, wid: CGWindowID) {
        var psn = ProcessSerialNumber()
        if processForPID(target.pid, &psn) == noErr {
            _ = setFrontProcess(&psn, wid, cpsUserGenerated)
            makeKeyWindow(&psn, wid)
        } else {
            NSRunningApplication(processIdentifier: target.pid)?.activate()
        }
        if let axWindow {
            AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        }
    }

    static func axWindow(for target: WindowInfo) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(target.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return nil }
        return windows.first { windowID($0).map(target.ids.contains) ?? false }
            ?? windows.first { frame($0)?.isRoughly(target.frame) ?? false }
    }

    static func windowID(_ element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return axWindowID(element, &id) == .success && id != 0 ? id : nil
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let posValue, let sizeValue
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }
}
