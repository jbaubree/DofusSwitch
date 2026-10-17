// Sources/DofusSwitch/UI/SettingsView.swift
import SwiftUI
import DofusSwitchCore

struct SettingsView: View {
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    @Binding var hotkeysEnabled: Bool
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raccourcis globaux").font(.headline)
                Spacer()
                Toggle("", isOn: $hotkeysEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack {
                Text("Fenêtre suivante")
                Spacer()
                HotkeyRecorderField(binding: $nextHotkey, label: "next")
                    .frame(width: 160, height: 24)
            }
            .opacity(hotkeysEnabled ? 1 : 0.4)
            HStack {
                Text("Fenêtre précédente")
                Spacer()
                HotkeyRecorderField(binding: $prevHotkey, label: "prev")
                    .frame(width: 160, height: 24)
            }
            .opacity(hotkeysEnabled ? 1 : 0.4)

            Divider()

            Toggle("Démarrer au login", isOn: $launchAtLogin)

            Divider()

            Button("Réinitialiser") { onReset() }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(16)
    }
}
