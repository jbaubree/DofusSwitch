import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let dofusBundleId: String

    init(rootView: AnyView, dofusBundleId: String = "com.Ankama.Dofus") {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.dofusBundleId = dofusBundleId
        super.init()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        refreshIcon()
    }

    /// Set the menu-bar icon to the Dofus app icon if Dofus is running,
    /// otherwise fall back to the SF Symbol. Safe to call repeatedly.
    func refreshIcon() {
        guard let button = statusItem.button else { return }
        if let icon = NSRunningApplication
            .runningApplications(withBundleIdentifier: dofusBundleId)
            .first?.icon
        {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            button.image = icon
        } else {
            button.image = NSImage(
                systemSymbolName: "square.grid.3x1.below.line.grid.1x2",
                accessibilityDescription: "DofusSwitch"
            )
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
