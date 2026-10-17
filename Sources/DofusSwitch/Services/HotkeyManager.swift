// Sources/DofusSwitch/Services/HotkeyManager.swift
import Carbon.HIToolbox
import DofusSwitchCore

public enum HotkeyID: UInt32 {
    case next = 1
    case prev = 2
}

public final class HotkeyManager {
    public var onHotkey: ((HotkeyID) -> Void)?

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?

    public init() {
        installHandler()
    }

    deinit {
        if let handlerRef { RemoveEventHandler(handlerRef) }
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
    }

    public func rebind(next: HotkeyBinding, prev: HotkeyBinding) {
        unregister(.next)
        unregister(.prev)
        register(id: .next, binding: next)
        register(id: .prev, binding: prev)
    }

    private func register(id: HotkeyID, binding: HotkeyBinding) {
        var hotKeyID = EventHotKeyID(signature: OSType(0x44535748 /* 'DSWH' */), id: id.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            refs[id.rawValue] = ref
        } else {
            NSLog("DofusSwitch: RegisterEventHotKey failed for id=\(id) status=\(status)")
        }
    }

    private func unregister(_ id: HotkeyID) {
        if let ref = refs.removeValue(forKey: id.rawValue) {
            UnregisterEventHotKey(ref)
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var id = EventHotKeyID()
                let s = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard s == noErr else { return noErr }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let hk = HotkeyID(rawValue: id.id) {
                    DispatchQueue.main.async { mgr.onHotkey?(hk) }
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &handlerRef
        )
    }
}
