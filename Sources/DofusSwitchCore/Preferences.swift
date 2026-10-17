// Sources/DofusSwitchCore/Preferences.swift
import Foundation

public struct Preferences: Codable, Equatable {
    public var nextHotkey: HotkeyBinding
    public var prevHotkey: HotkeyBinding
    public var windowOrder: [String]   // normalized title keys
    public var launchAtLogin: Bool
    public var hotkeysEnabled: Bool

    public init(
        nextHotkey: HotkeyBinding,
        prevHotkey: HotkeyBinding,
        windowOrder: [String],
        launchAtLogin: Bool,
        hotkeysEnabled: Bool = true
    ) {
        self.nextHotkey = nextHotkey
        self.prevHotkey = prevHotkey
        self.windowOrder = windowOrder
        self.launchAtLogin = launchAtLogin
        self.hotkeysEnabled = hotkeysEnabled
    }

    // Custom decoding keeps existing stored prefs loadable after new fields are added:
    // a missing hotkeysEnabled defaults to true.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nextHotkey = try c.decode(HotkeyBinding.self, forKey: .nextHotkey)
        self.prevHotkey = try c.decode(HotkeyBinding.self, forKey: .prevHotkey)
        self.windowOrder = try c.decode([String].self, forKey: .windowOrder)
        self.launchAtLogin = try c.decode(Bool.self, forKey: .launchAtLogin)
        self.hotkeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeysEnabled) ?? true
    }

    public static let defaults = Preferences(
        nextHotkey: .defaultNext,
        prevHotkey: .defaultPrev,
        windowOrder: [],
        launchAtLogin: false,
        hotkeysEnabled: true
    )
}
