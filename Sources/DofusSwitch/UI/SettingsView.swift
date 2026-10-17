// Sources/DofusSwitch/UI/SettingsView.swift
import SwiftUI
import DofusSwitchCore

struct SettingsView: View {
    @Binding var nextHotkey: HotkeyBinding
    @Binding var prevHotkey: HotkeyBinding
    @Binding var launchAtLogin: Bool
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raccourcis globaux").font(.headline)

            HStack {
                Text("Fenêtre suivante")
                Spacer()
                HotkeyRecorderField(binding: $nextHotkey, label: "next")
                    .frame(width: 160, height: 24)
            }
            HStack {
                Text("Fenêtre précédente")
                Spacer()
                HotkeyRecorderField(binding: $prevHotkey, label: "prev")
                    .frame(width: 160, height: 24)
            }

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
