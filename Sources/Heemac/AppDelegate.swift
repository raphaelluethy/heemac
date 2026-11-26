import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let hotkeys = Hotkeys()
    private var statusItem: NSStatusItem!
    private var unavailable: Set<String> = []
    private var resetGaze: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        for binding in Binding.all {
            let direction = binding.direction
            let registered = hotkeys.register(keyCode: binding.keyCode, modifiers: Binding.modifiers) { [weak self] in
                let moved = Navigator.move(direction)
                self?.show(moved ? .look(direction) : .blink)
            }
            if !registered {
                unavailable.insert(binding.key)
                Navigator.log.error("could not register \(Binding.modifierSymbols, privacy: .public)\(binding.key, privacy: .public)")
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Logo.menuBarImage(.center)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Shows the mascot's reaction briefly, then returns it to looking ahead.
    private func show(_ gaze: Gaze) {
        statusItem.button?.image = Logo.menuBarImage(gaze)
        resetGaze?.cancel()
        let reset = DispatchWorkItem { [weak self] in self?.statusItem.button?.image = Logo.menuBarImage(.center) }
        resetGaze = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: reset)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "Heemac", action: nil, keyEquivalent: "")

        if AXIsProcessTrusted() {
            menu.addItem(withTitle: "Accessibility: granted", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(item("Grant Accessibility Access…", #selector(openAccessibilitySettings)))
        }
        menu.addItem(.separator())

        for binding in Binding.all {
            let note = unavailable.contains(binding.key) ? "  (in use by another app)" : ""
            menu.addItem(withTitle: "\(Binding.modifierSymbols)\(binding.key)  Focus \(binding.direction.rawValue)\(note)",
                         action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())

        let login = item("Open at Login", #selector(toggleLoginItem))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Quit Heemac", #selector(quit)))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func toggleLoginItem() {
        LoginItem.set(!LoginItem.isEnabled)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            Navigator.log.error("login item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
