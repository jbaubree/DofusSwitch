// Tests/DofusSwitchCoreTests/WindowStoreTests.swift
import XCTest
@testable import DofusSwitchCore

final class WindowStoreTests: XCTestCase {
    private func makeStore(order: [String] = []) -> WindowStore {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let prefs = Preferences(
            nextHotkey: .defaultNext,
            prevHotkey: .defaultPrev,
            windowOrder: order,
            launchAtLogin: false
        )
        let prefsStore = PreferencesStore(defaults: defaults)
        prefsStore.save(prefs)
        return WindowStore(preferencesStore: prefsStore)
    }

    private func w(_ title: String, pid: pid_t = 1) -> TrackedWindow {
        TrackedWindow(title: title, pid: pid)
    }

    func test_update_withEmptyOrder_appendsInDetectedOrder() {
        let store = makeStore()
        store.update(detected: [w("Perso1"), w("Perso2")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso1", "Perso2"])
    }

    func test_update_respectsPersistedOrder() {
        let store = makeStore(order: ["perso2", "perso1"])
        store.update(detected: [w("Perso1"), w("Perso2")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso2", "Perso1"])
    }

    func test_update_newWindows_appendInDetectedOrderAfterKnown() {
        let store = makeStore(order: ["perso1"])
        store.update(detected: [w("Perso2"), w("Perso1"), w("Perso3")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso1", "Perso2", "Perso3"])
    }

    func test_update_absentPersistedWindows_arePreservedButHidden() {
        let store = makeStore(order: ["perso1", "perso2", "perso3"])
        store.update(detected: [w("Perso2")])
        XCTAssertEqual(store.visibleWindows.map(\.title), ["Perso2"])
        XCTAssertEqual(store.persistedOrder, ["perso1", "perso2", "perso3"])
    }

    func test_move_persistsAndReorders() {
        let store = makeStore()
        store.update(detected: [w("A"), w("B"), w("C")])
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3) // A → after C
        XCTAssertEqual(store.visibleWindows.map(\.title), ["B", "C", "A"])
        XCTAssertEqual(store.persistedOrder, ["b", "c", "a"])
    }

    func test_update_removesPhantomWhenNeverSeen_isDisabled() {
        // Behavior: phantoms are kept forever (purge is a user action, not automatic).
        let store = makeStore(order: ["ghost"])
        store.update(detected: [])
        XCTAssertEqual(store.persistedOrder, ["ghost"])
    }
}
