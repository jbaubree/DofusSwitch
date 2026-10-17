import SwiftUI

@main
struct DofusSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Empty — all UI is in the menu bar popover, driven by AppDelegate.
        Settings { EmptyView() }
    }
}
