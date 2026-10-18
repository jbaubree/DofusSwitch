// Sources/DofusSwitch/UI/WindowListView.swift
import AppKit
import SwiftUI
import DofusSwitchCore

struct WindowListView: View {
    @ObservedObject var store: WindowStore
    var currentWindowKey: String?

    var body: some View {
        if store.visibleWindows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.3.offgrid.bubble.left")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Aucune fenêtre Dofus détectée")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.visibleWindows) { window in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, height: 16)
                        iconFor(pid: window.pid)
                        Text(window.displayTitle).lineLimit(1)
                        Spacer()
                        if window.normalizedKey == currentWindowKey {
                            Image(systemName: "dot.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove { offsets, destination in
                    store.move(fromOffsets: offsets, toOffset: destination)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func iconFor(pid: pid_t) -> some View {
        if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "gamecontroller")
                .foregroundStyle(.secondary)
        }
    }
}
