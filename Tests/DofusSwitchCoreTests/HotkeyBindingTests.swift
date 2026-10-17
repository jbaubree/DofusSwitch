// Tests/DofusSwitchCoreTests/HotkeyBindingTests.swift
import XCTest
@testable import DofusSwitchCore

final class HotkeyBindingTests: XCTestCase {
    // Carbon modifier constants (duplicated here to avoid importing Carbon in tests)
    private let cmdKey: UInt32 = 1 << 8
    private let shiftKey: UInt32 = 1 << 9
    private let optionKey: UInt32 = 1 << 11
    private let controlKey: UInt32 = 1 << 12

    // NSEvent raw masks (device-independent)
    private let nsCommand: UInt = 1 << 20
    private let nsShift: UInt = 1 << 17
    private let nsOption: UInt = 1 << 19
    private let nsControl: UInt = 1 << 18

    func test_carbonModifiers_fromNSEventFlags_singleModifiers() {
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsCommand), cmdKey)
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsShift), shiftKey)
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsOption), optionKey)
        XCTAssertEqual(HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: nsControl), controlKey)
    }

    func test_carbonModifiers_combined() {
        let combined = nsCommand | nsOption | nsControl
        XCTAssertEqual(
            HotkeyBinding.carbonModifiers(fromNSEventFlagsRaw: combined),
            cmdKey | optionKey | controlKey
        )
    }

    func test_defaultNext_isControlOptionRightArrow() {
        let b = HotkeyBinding.defaultNext
        XCTAssertEqual(b.keyCode, 0x7C) // kVK_RightArrow
        XCTAssertEqual(b.carbonModifiers, controlKey | optionKey)
    }

    func test_defaultPrev_isControlOptionLeftArrow() {
        let b = HotkeyBinding.defaultPrev
        XCTAssertEqual(b.keyCode, 0x7B) // kVK_LeftArrow
        XCTAssertEqual(b.carbonModifiers, controlKey | optionKey)
    }

    func test_codableRoundTrip() throws {
        let b = HotkeyBinding(keyCode: 0x24, carbonModifiers: cmdKey | shiftKey)
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        XCTAssertEqual(decoded, b)
    }
}
