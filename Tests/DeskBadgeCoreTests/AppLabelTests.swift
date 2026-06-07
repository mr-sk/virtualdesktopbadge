import XCTest
@testable import DeskBadgeCore

final class AppLabelTests: XCTestCase {
    func test_empty_list_is_empty_string() {
        XCTAssertEqual(AppLabel.format([]), "")
    }

    func test_single_app() {
        XCTAssertEqual(AppLabel.format(["Zed"]), "Zed")
    }

    func test_up_to_three_apps_joined() {
        XCTAssertEqual(AppLabel.format(["Zed", "iTerm2", "Brave"]), "Zed, iTerm2, Brave")
    }

    func test_more_than_three_apps_get_plus_suffix() {
        XCTAssertEqual(
            AppLabel.format(["Zed", "iTerm2", "Brave", "Slack", "Notes"]),
            "Zed, iTerm2, Brave +2"
        )
    }

    func test_names_truncated_to_max_chars_with_ellipsis() {
        // Two apps, names exceed the cap → truncate the names to maxChars.
        let result = AppLabel.format(["VeryLongApplicationName", "Another"], maxApps: 3, maxChars: 10)
        XCTAssertEqual(result, "VeryLongA…")
        XCTAssertLessThanOrEqual(result.count, 10)
    }

    func test_truncation_keeps_plus_suffix_visible() {
        let result = AppLabel.format(["LongNameApp", "B", "C", "D", "E"], maxApps: 3, maxChars: 8)
        XCTAssertEqual(result, "LongNam… +2")
    }
}
