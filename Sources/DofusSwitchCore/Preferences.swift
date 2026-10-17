// Sources/DofusSwitchCore/Preferences.swift
import Foundation

public struct Preferences: Codable, Equatable {
    public var nextHotkey: HotkeyBinding
    public var prevHotkey: HotkeyBinding
    public var windowOrder: [String]   // normalized title keys
    public var launchAtLogin: Bool

    public init(nextHotkey: HotkeyBinding, prevHotkey: HotkeyBinding, windowOrder: [String], launchAtLogin: Bool) {
        self.nextHotkey = nextHotkey
        self.prevHotkey = prevHotkey
        self.windowOrder = windowOrder
        self.launchAtLogin = launchAtLogin
    }

    public static let defaults = Preferences(
        nextHotkey: .defaultNext,
        prevHotkey: .defaultPrev,
        windowOrder: [],
        launchAtLogin: false
    )
}
