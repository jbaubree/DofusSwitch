// Sources/DofusSwitch/UI/PopoverRootView.swift
import SwiftUI
import DofusSwitchCore

struct PopoverRootView: View {
    @ObservedObject var store: WindowStore
    @State private var showSettings = false
    @State private var axGranted: Bool = AccessibilityPermission.isTrusted(prompt: false)

    let currentWindowKey: () -> String?
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    let onReset: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !axGranted {
                OnboardingView(onRecheck: {
                    axGranted = AccessibilityPermission.isTrusted(prompt: true)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showSettings {
                SettingsView(
                    nextHotkey: $nextHotkey,
                    prevHotkey: $prevHotkey,
                    launchAtLogin: $launchAtLogin,
                    onReset: onReset
                )
            } else {
                WindowListView(store: store, currentWindowKey: currentWindowKey())
            }
            Divider()
            footer
        }
        .frame(width: 280, height: 360)
    }

    private var header: some View {
        HStack {
            if showSettings {
                Button(action: { showSettings = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text("Settings").font(.system(size: 13, weight: .semibold))
            } else {
                Text("Dofus windows").font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
