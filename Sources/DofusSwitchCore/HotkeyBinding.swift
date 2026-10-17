// Sources/DofusSwitchCore/HotkeyBinding.swift
import Foundation

public struct HotkeyBinding: Codable, Equatable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    // Carbon modifier bits (from Carbon.HIToolbox.Events, duplicated so Core avoids Carbon import).
    public static let carbonCmd: UInt32    = 1 << 8
    public static let carbonShift: UInt32  = 1 << 9
    public static let carbonOption: UInt32 = 1 << 11
    public static let carbonControl: UInt32 = 1 << 12

    // NSEvent.ModifierFlags raw bit positions (stable, documented).
    private static let nsCommand: UInt = 1 << 20
    private static let nsShift: UInt   = 1 << 17
    private static let nsOption: UInt  = 1 << 19
    private static let nsControl: UInt = 1 << 18

    /// Converts raw `NSEvent.ModifierFlags.rawValue` bits to the Carbon modifier mask
    /// that `RegisterEventHotKey` expects.
    public static func carbonModifiers(fromNSEventFlagsRaw raw: UInt) -> UInt32 {
        var out: UInt32 = 0
        if raw & nsCommand != 0 { out |= carbonCmd }
        if raw & nsShift   != 0 { out |= carbonShift }
        if raw & nsOption  != 0 { out |= carbonOption }
        if raw & nsControl != 0 { out |= carbonControl }
        return out
    }

    public static let defaultNext = HotkeyBinding(
        keyCode: 0x7C, // kVK_RightArrow
        carbonModifiers: carbonControl | carbonOption
    )

    public static let defaultPrev = HotkeyBinding(
        keyCode: 0x7B, // kVK_LeftArrow
        carbonModifiers: carbonControl | carbonOption
    )
}
