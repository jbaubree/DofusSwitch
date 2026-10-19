// Tests/DofusSwitchCoreTests/HotkeyActivationTests.swift
import XCTest
@testable import DofusSwitchCore

final class HotkeyActivationTests: XCTestCase {
    func test_disabledWhenToggleOff_zeroSessions() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: false, sessionCount: 0))
    }

    func test_disabledWhenToggleOff_oneSession() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: false, sessionCount: 1))
    }

    func test_disabledWhenToggleOff_manySessions() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: false, sessionCount: 5))
    }

    func test_disabledWhenToggleOn_zeroSessions() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 0))
    }

    func test_disabledWhenToggleOn_oneSession() {
        XCTAssertFalse(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 1))
    }

    func test_enabledWhenToggleOn_twoSessions() {
        XCTAssertTrue(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 2))
    }

    func test_enabledWhenToggleOn_manySessions() {
        XCTAssertTrue(shouldEnableHotkeys(preferredEnabled: true, sessionCount: 10))
    }

    func test_minimumSessionsConstantIsTwo() {
        XCTAssertEqual(hotkeyMinimumSessions, 2)
    }
}
