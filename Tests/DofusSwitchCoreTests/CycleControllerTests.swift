import XCTest
@testable import DofusSwitchCore

final class CycleControllerTests: XCTestCase {
    private func w(_ t: String) -> TrackedWindow { TrackedWindow(title: t, pid: 1) }

    func test_next_fromNoCurrent_returnsFirst() {
        let c = CycleController()
        let target = c.next(in: [w("A"), w("B"), w("C")])
        XCTAssertEqual(target?.title, "A")
    }

    func test_next_wrapsAtEnd() {
        let c = CycleController()
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "a"
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "b"
        let target = c.next(in: [w("A"), w("B")])
        XCTAssertEqual(target?.title, "A")
    }

    func test_prev_fromNoCurrent_returnsLast() {
        let c = CycleController()
        let target = c.prev(in: [w("A"), w("B"), w("C")])
        XCTAssertEqual(target?.title, "C")
    }

    func test_prev_wrapsAtStart() {
        let c = CycleController()
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "a"
        let target = c.prev(in: [w("A"), w("B")])
        XCTAssertEqual(target?.title, "B")
    }

    func test_emptyList_returnsNil() {
        let c = CycleController()
        XCTAssertNil(c.next(in: []))
        XCTAssertNil(c.prev(in: []))
    }

    func test_singleElement_alwaysReturnsThatElement() {
        let c = CycleController()
        XCTAssertEqual(c.next(in: [w("Only")])?.title, "Only")
        XCTAssertEqual(c.next(in: [w("Only")])?.title, "Only")
        XCTAssertEqual(c.prev(in: [w("Only")])?.title, "Only")
    }

    func test_currentNoLongerPresent_restartsAtFirstForNext() {
        let c = CycleController()
        _ = c.next(in: [w("A"), w("B")]) // currentKey = "a"
        let target = c.next(in: [w("C"), w("D")]) // "a" absent
        XCTAssertEqual(target?.title, "C")
    }
}
