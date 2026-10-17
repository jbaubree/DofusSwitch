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
}
