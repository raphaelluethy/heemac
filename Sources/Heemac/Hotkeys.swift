import Carbon

struct Binding {
    let key: String
    let keyCode: UInt32
    let direction: Direction

    /// Hyper (⌃⌥⌘) plus Shift.
    static let modifiers = UInt32(cmdKey | controlKey | optionKey | shiftKey)
    static let modifierSymbols = "⌃⌥⇧⌘"

    static let all = [
        Binding(key: "H", keyCode: UInt32(kVK_ANSI_H), direction: .left),
        Binding(key: "J", keyCode: UInt32(kVK_ANSI_J), direction: .down),
        Binding(key: "K", keyCode: UInt32(kVK_ANSI_K), direction: .up),
        Binding(key: "L", keyCode: UInt32(kVK_ANSI_L), direction: .right),
    ]
}

/// Global hotkeys via Carbon, which needs no extra permission. Carbon delivers
/// hotkey events on the main thread.
@MainActor
final class Hotkeys {
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x4845_4D43 // "HEMC"

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            guard status == noErr else { return status }
            let id = hotkeyID.id
            MainActor.assumeIsolated { Unmanaged<Hotkeys>.fromOpaque(userData).takeUnretainedValue().actions[id]?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// Returns false when the combination could not be registered.
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        actions[id] = action
        return true
    }
}
