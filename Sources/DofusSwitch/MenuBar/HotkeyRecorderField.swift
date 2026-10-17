// Sources/DofusSwitch/MenuBar/HotkeyRecorderField.swift
import AppKit
import SwiftUI
import DofusSwitchCore

struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var binding: HotkeyBinding
    var label: String

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = { keyCode, flagsRaw in
            self.binding = HotkeyBinding(
                keyCode: UInt32(keyCode),
                carbonModifiers: HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: flagsRaw)
            )
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.label = label
        nsView.binding = binding
        nsView.needsDisplay = true
    }
}

final class RecorderNSView: NSView {
    var label: String = ""
    var binding: HotkeyBinding = .defaultNext
    var onCapture: ((UInt16, UInt) -> Void)?

    private var capturing = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 180, height: 24) }

    override func mouseDown(with event: NSEvent) {
        capturing = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard capturing else { super.keyDown(with: event); return }
        // Escape cancels capture without binding anything.
        if event.keyCode == 0x35 {
            capturing = false
            needsDisplay = true
            return
        }
        onCapture?(event.keyCode, event.modifierFlags.rawValue)
        capturing = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = capturing ? NSColor.selectedControlColor : NSColor.controlBackgroundColor
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()

        let text = capturing ? "Appuyez sur une touche… (Esc annule)" : prettyPrint(binding)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private func prettyPrint(_ b: HotkeyBinding) -> String {
        var parts: [String] = []
        if b.carbonModifiers & HotkeyBinding.carbonControl != 0 { parts.append("⌃") }
        if b.carbonModifiers & HotkeyBinding.carbonOption  != 0 { parts.append("⌥") }
        if b.carbonModifiers & HotkeyBinding.carbonShift   != 0 { parts.append("⇧") }
        if b.carbonModifiers & HotkeyBinding.carbonCmd     != 0 { parts.append("⌘") }
        parts.append(keyName(for: b.keyCode))
        return parts.joined()
    }

    private func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0x7C: return "→"
        case 0x7B: return "←"
        case 0x7E: return "↑"
        case 0x7D: return "↓"
        default: return "key(\(keyCode))"
        }
    }
}
