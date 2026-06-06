import XCTest
@testable import DeskBadgeCore

final class SpaceIndexTests: XCTestCase {
    func test_index_is_one_based_position() {
        XCTAssertEqual(spaceIndex(orderedSpaceIDs: [5, 7, 9], activeSpaceID: 7), 2)
        XCTAssertEqual(spaceIndex(orderedSpaceIDs: [5, 7, 9], activeSpaceID: 5), 1)
    }

    func test_index_nil_when_active_not_in_list() {
        XCTAssertNil(spaceIndex(orderedSpaceIDs: [5, 7], activeSpaceID: 99))
    }

    func test_resolve_uses_matching_display() {
        let displays = [
            DisplaySpaces(uuid: "A", orderedSpaceIDs: [1, 2], currentSpaceID: 2),
            DisplaySpaces(uuid: "B", orderedSpaceIDs: [3, 4, 5], currentSpaceID: 5),
        ]
        XCTAssertEqual(resolveIndex(displays: displays, activeDisplayUUID: "B"), 3)
    }

    func test_resolve_falls_back_to_first_display_when_uuid_unknown() {
        let displays = [
            DisplaySpaces(uuid: "A", orderedSpaceIDs: [1, 2], currentSpaceID: 2),
        ]
        XCTAssertEqual(resolveIndex(displays: displays, activeDisplayUUID: "ZZZ"), 2)
    }

    func test_resolve_nil_when_no_displays() {
        XCTAssertNil(resolveIndex(displays: [], activeDisplayUUID: "A"))
    }
}
