// Sources/DofusSwitch/UI/OnboardingView.swift
import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    var onRecheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Autorisation requise")
                .font(.headline)
            Text("DofusSwitch a besoin de la permission Accessibilité pour détecter et focaliser les fenêtres Dofus.")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Ouvrir Réglages Système") { openSettings() }
                Button("Revérifier") { onRecheck() }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}
