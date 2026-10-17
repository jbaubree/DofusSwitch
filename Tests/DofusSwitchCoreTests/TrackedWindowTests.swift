import XCTest
@testable import DofusSwitchCore

final class TrackedWindowTests: XCTestCase {
    func test_normalizedKey_lowercasesAndTrims() {
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "  Perso1  "), "perso1")
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "PERSO1"), "perso1")
    }

    func test_normalizedKey_collapsesInternalWhitespace() {
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "Perso  Un"), "perso un")
    }

    func test_normalizedKey_returnsEmptyStringForWhitespaceOnly() {
        XCTAssertEqual(TrackedWindow.normalizedKey(from: "   "), "")
    }

    func test_stripVersionSuffix_removesTrailingVersion() {
        XCTAssertEqual(TrackedWindow.stripVersionSuffix(from: "Myrdak - Iop - 3.7.11.6"), "Myrdak - Iop")
    }

    func test_stripVersionSuffix_keepsPlainNameClasse() {
        XCTAssertEqual(TrackedWindow.stripVersionSuffix(from: "Myrdak - Iop"), "Myrdak - Iop")
    }

    func test_stripVersionSuffix_keepsSingleWord() {
        XCTAssertEqual(TrackedWindow.stripVersionSuffix(from: "Myrdak"), "Myrdak")
    }

    func test_stripVersionSuffix_dropsVersionEvenWithOneDash() {
        XCTAssertEqual(TrackedWindow.stripVersionSuffix(from: "Myrdak - 3.7.11.6"), "Myrdak")
    }

    func test_displayTitle_matchesStripped() {
        let w = TrackedWindow(title: "Myrdak - Iop - 3.7.11.6", pid: 1)
        XCTAssertEqual(w.displayTitle, "Myrdak - Iop")
    }

    func test_normalizedKey_isDerivedFromDisplayTitle() {
        let w = TrackedWindow(title: "Myrdak - Iop - 3.7.11.6", pid: 1)
        XCTAssertEqual(w.normalizedKey, "myrdak - iop")
    }
}
