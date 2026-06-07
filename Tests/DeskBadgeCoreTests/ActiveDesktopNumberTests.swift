import XCTest
@testable import DeskBadgeCore

final class ActiveDesktopNumberTests: XCTestCase {
    // Main display "A" has many desktops; second display "B" has one.
    private func twoDisplays(aCurrent: Int) -> [DisplaySpaces] {
        [
            DisplaySpaces(uuid: "A", orderedSpaceIDs: [1, 3, 4, 5, 6], currentSpaceID: aCurrent),
            DisplaySpaces(uuid: "B", orderedSpaceIDs: [32], currentSpaceID: 32),
        ]
    }

    // The reported bug: the main display's desktop changed (now position 4 = id 5),
    // while the focused/mouse display is the single-desktop "B". The number must
    // follow the display that CHANGED (A → 4), not the focused one (B → 1).
    func test_reports_display_whose_desktop_changed_not_focused() {
        let previous = ["A": 4, "B": 32]            // A was on id 4 (position 3)
        let displays = twoDisplays(aCurrent: 5)      // A switched to id 5 (position 4)
        let number = activeDesktopNumber(previous: previous, displays: displays, focusedUUID: "B")
        XCTAssertEqual(number, 4)
    }

    func test_returns_nil_when_nothing_changed() {
        let previous = ["A": 5, "B": 32]
        let displays = twoDisplays(aCurrent: 5)      // identical to previous
        XCTAssertNil(activeDesktopNumber(previous: previous, displays: displays, focusedUUID: "B"))
    }

    // First read (no previous snapshot): prefer the focused display.
    func test_first_read_prefers_focused_display() {
        let displays = twoDisplays(aCurrent: 5)
        let number = activeDesktopNumber(previous: [:], displays: displays, focusedUUID: "B")
        XCTAssertEqual(number, 1)                     // B's only desktop
    }

    // First read with focused display unknown: fall back to the first display.
    func test_first_read_falls_back_to_first_display() {
        let displays = twoDisplays(aCurrent: 5)
        let number = activeDesktopNumber(previous: [:], displays: displays, focusedUUID: nil)
        XCTAssertEqual(number, 4)                     // A's current (id 5 → position 4)
    }

    func test_nil_when_no_displays() {
        XCTAssertNil(activeDesktopNumber(previous: [:], displays: [], focusedUUID: "A"))
    }

    // A newly connected display (absent from the snapshot) is not treated as
    // "the switch" — only a display whose KNOWN current value changed counts.
    func test_ignores_newly_seen_display_for_change_detection() {
        let previous = ["A": 5]                       // B not yet known
        let displays = twoDisplays(aCurrent: 5)        // A unchanged; B is new
        XCTAssertNil(activeDesktopNumber(previous: previous, displays: displays, focusedUUID: "B"))
    }

    func test_snapshot_maps_uuid_to_current_space() {
        let snapshot = currentSpaceSnapshot(twoDisplays(aCurrent: 5))
        XCTAssertEqual(snapshot, ["A": 5, "B": 32])
    }
}
