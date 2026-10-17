// Sources/DofusSwitch/Services/FocusService.swift
import AppKit
import ApplicationServices
import DofusSwitchCore

public final class FocusService {
    public init() {}

    @discardableResult
    public func focus(_ window: TrackedWindow) -> Bool {
        guard let axRef = window.axElementRef else { return false }
        let axWindow = axRef as! AXUIElement

        _ = AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)

        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return false }
        app.activate(options: [.activateIgnoringOtherApps])
        return true
    }
}
