import XCTest
@testable import DeskBadgeCore

final class DisplaySpacesTests: XCTestCase {
    func test_parses_uuid_ordered_ids_and_current() {
        let raw: [[String: Any]] = [
            [
                "Display Identifier": "DISPLAY-A",
                "Current Space": ["ManagedSpaceID": 7],
                "Spaces": [
                    ["ManagedSpaceID": 5],
                    ["ManagedSpaceID": 7],
                    ["ManagedSpaceID": 9],
                ],
            ]
        ]
        let parsed = parseDisplaySpaces(raw)
        XCTAssertEqual(parsed, [
            DisplaySpaces(uuid: "DISPLAY-A",
                          orderedSpaceIDs: [5, 7, 9],
                          currentSpaceID: 7)
        ])
    }

    func test_skips_entries_without_display_identifier() {
        let raw: [[String: Any]] = [["Spaces": []]]
        XCTAssertEqual(parseDisplaySpaces(raw), [])
    }

    func test_falls_back_to_id64_when_managed_id_absent() {
        let raw: [[String: Any]] = [
            [
                "Display Identifier": "DISPLAY-B",
                "Current Space": ["id64": 42],
                "Spaces": [["id64": 42]],
            ]
        ]
        XCTAssertEqual(parseDisplaySpaces(raw), [
            DisplaySpaces(uuid: "DISPLAY-B", orderedSpaceIDs: [42], currentSpaceID: 42)
        ])
    }
}
