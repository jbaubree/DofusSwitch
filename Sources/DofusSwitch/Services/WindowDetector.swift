import AppKit
import ApplicationServices
import DofusSwitchCore

public final class WindowDetector {
    public var onUpdate: (([TrackedWindow]) -> Void)?

    // TODO: verify at runtime with real Dofus Unity client (Task 17 smoke test).
    private let dofusBundleId = "com.ankama.dofus"

    private var observers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?

    public init() {
        subscribeWorkspace()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for (_, obs) in observers {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
        }
    }

    public func scanNow() {
        let detected = currentDofusApps().flatMap { trackedWindows(for: $0) }
        onUpdate?(detected)
        syncObservers()
    }

    // MARK: - NSWorkspace

    private func subscribeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                       object: nil, queue: .main) { [weak self] _ in self?.scanNow() }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                       object: nil, queue: .main) { [weak self] _ in self?.scanNow() }
    }

    private func currentDofusApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter(isDofusApp)
    }

    private func isDofusApp(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == dofusBundleId
    }

    // MARK: - AX API

    private func trackedWindows(for app: NSRunningApplication) -> [TrackedWindow] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: AnyObject?
        let s = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        guard s == .success, let axWindows = value as? [AXUIElement] else { return [] }

        return axWindows.compactMap { axWindow -> TrackedWindow? in
            var titleRef: AnyObject?
            guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                  let title = titleRef as? String,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return TrackedWindow(
                title: title,
                pid: app.processIdentifier,
                axElementRef: axWindow as AnyObject
            )
        }
    }

    // MARK: - AX observers per app

    private func syncObservers() {
        let currentPids = Set(currentDofusApps().map(\.processIdentifier))
        // Remove observers for dead apps.
        for (pid, obs) in observers where !currentPids.contains(pid) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
            observers.removeValue(forKey: pid)
        }
        // Add observers for new apps.
        for pid in currentPids where observers[pid] == nil {
            installObserver(pid: pid)
        }
    }

    private func installObserver(pid: pid_t) {
        var observer: AXObserver?
        let s = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            let detector = Unmanaged<WindowDetector>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { detector.scanNow() }
        }, &observer)
        guard s == .success, let observer else { return }

        let axApp = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for notif in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification, kAXTitleChangedNotification] {
            AXObserverAddNotification(observer, axApp, notif as CFString, selfPtr)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                          AXObserverGetRunLoopSource(observer),
                          .defaultMode)
        observers[pid] = observer
    }

    // MARK: - Fallback poll

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanNow()
        }
    }
}
