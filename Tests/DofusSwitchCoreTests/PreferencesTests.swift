// Tests/DofusSwitchCoreTests/PreferencesTests.swift
import XCTest
@testable import DofusSwitchCore

final class PreferencesTests: XCTestCase {
    private func makeStore() -> (PreferencesStore, UserDefaults) {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (PreferencesStore(defaults: defaults), defaults)
    }

    func test_load_returnsDefaultsWhenEmpty() {
        let (store, _) = makeStore()
        let prefs = store.load()
        XCTAssertEqual(prefs.nextHotkey, .defaultNext)
        XCTAssertEqual(prefs.prevHotkey, .defaultPrev)
        XCTAssertEqual(prefs.windowOrder, [])
        XCTAssertFalse(prefs.launchAtLogin)
    }

    func test_save_thenLoad_roundTripsAllFields() {
        let (store, _) = makeStore()
        var prefs = Preferences.defaults
        prefs.windowOrder = ["perso1", "perso2"]
        prefs.launchAtLogin = true
        prefs.nextHotkey = HotkeyBinding(keyCode: 1, carbonModifiers: 2)
        store.save(prefs)

        let loaded = store.load()
        XCTAssertEqual(loaded, prefs)
    }

    func test_load_fallsBackToDefaultsOnCorruptData() {
        let (store, defaults) = makeStore()
        defaults.set(Data([0xFF, 0xFF]), forKey: PreferencesStore.storageKey)
        XCTAssertEqual(store.load(), .defaults)
    }
}
