// Sources/DofusSwitch/AppDelegate.swift
import AppKit
import SwiftUI
import DofusSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    private let preferencesStore = PreferencesStore()
    private lazy var windowStore = WindowStore(preferencesStore: preferencesStore)
    private let cycleController = CycleController()
    private let focusService = FocusService()
    private let hotkeyManager = HotkeyManager()
    private let detector = WindowDetector()
    private let launchAtLogin = LaunchAtLoginService()

    private var prefs: Preferences = PreferencesStore().load()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Prompt for Accessibility on first launch (non-blocking).
        _ = AccessibilityPermission.isTrusted(prompt: true)

        // Detector → store
        detector.onUpdate = { [weak self] windows in
            self?.windowStore.update(detected: windows)
        }
        detector.scanNow()

        // Hotkeys
        hotkeyManager.onHotkey = { [weak self] id in
            guard let self else { return }
            let target: TrackedWindow?
            switch id {
            case .next: target = self.cycleController.next(in: self.windowStore.visibleWindows)
            case .prev: target = self.cycleController.prev(in: self.windowStore.visibleWindows)
            }
            if let t = target { self.focusService.focus(t) }
        }
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)

        // Menu bar
        let root = PopoverRootView(
            store: windowStore,
            currentWindowKey: { [weak self] in
                guard let self else { return nil }
                return self.cycleController.currentIndex(in: self.windowStore.visibleWindows)
                    .flatMap { self.windowStore.visibleWindows[$0].normalizedKey }
            },
            nextHotkey: Binding(
                get: { self.prefs.nextHotkey },
                set: { self.updateNextHotkey($0) }
            ),
            prevHotkey: Binding(
                get: { self.prefs.prevHotkey },
                set: { self.updatePrevHotkey($0) }
            ),
            launchAtLogin: Binding(
                get: { self.prefs.launchAtLogin },
                set: { self.updateLaunchAtLogin($0) }
            ),
            onReset: { [weak self] in self?.resetToDefaults() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBar = MenuBarController(rootView: AnyView(root))
    }

    // MARK: - Preference writes

    private func updateNextHotkey(_ b: HotkeyBinding) {
        prefs.nextHotkey = b
        preferencesStore.save(prefs)
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
    }

    private func updatePrevHotkey(_ b: HotkeyBinding) {
        prefs.prevHotkey = b
        preferencesStore.save(prefs)
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        prefs.launchAtLogin = enabled
        preferencesStore.save(prefs)
        launchAtLogin.set(enabled: enabled)
    }

    private func resetToDefaults() {
        prefs = .defaults
        preferencesStore.save(prefs)
        hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
        launchAtLogin.set(enabled: prefs.launchAtLogin)
    }
}
