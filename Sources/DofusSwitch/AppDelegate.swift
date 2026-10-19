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

        // Detector → store (+ refresh menu bar icon when Dofus launches/quits,
        // + re-evaluate hotkey registration when the session count changes).
        detector.onUpdate = { [weak self] windows in
            guard let self else { return }
            self.windowStore.update(detected: windows)
            self.menuBar?.refreshIcon()
            self.applyHotkeyState()
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
        applyHotkeyState()

        // Menu bar
        let root = PopoverRootView(
            store: windowStore,
            currentWindowKey: { [weak self] in
                guard let self else { return nil }
                return self.cycleController.currentIndex(in: self.windowStore.visibleWindows)
                    .flatMap { self.windowStore.visibleWindows[$0].normalizedKey }
            },
            sessionCount: { [weak self] in
                self?.windowStore.visibleWindows.count ?? 0
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
            hotkeysEnabled: Binding(
                get: { self.prefs.hotkeysEnabled },
                set: { self.updateHotkeysEnabled($0) }
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
        applyHotkeyState()
    }

    private func updatePrevHotkey(_ b: HotkeyBinding) {
        prefs.prevHotkey = b
        preferencesStore.save(prefs)
        applyHotkeyState()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        prefs.launchAtLogin = enabled
        preferencesStore.save(prefs)
        launchAtLogin.set(enabled: enabled)
    }

    private func updateHotkeysEnabled(_ enabled: Bool) {
        prefs.hotkeysEnabled = enabled
        preferencesStore.save(prefs)
        applyHotkeyState()
    }

    private func resetToDefaults() {
        prefs = .defaults
        preferencesStore.save(prefs)
        applyHotkeyState()
        launchAtLogin.set(enabled: prefs.launchAtLogin)
    }

    private func applyHotkeyState() {
        let effective = shouldEnableHotkeys(
            preferredEnabled: prefs.hotkeysEnabled,
            sessionCount: windowStore.visibleWindows.count
        )
        if effective {
            hotkeyManager.rebind(next: prefs.nextHotkey, prev: prefs.prevHotkey)
        } else {
            hotkeyManager.unregisterAll()
        }
    }
}
