// Sources/DofusSwitch/Services/LaunchAtLoginService.swift
import ServiceManagement

public final class LaunchAtLoginService {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("DofusSwitch: launch-at-login change failed: \(error)")
        }
    }
}
