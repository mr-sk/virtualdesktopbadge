import XCTest
import AppKit
@testable import DeskBadgeCore

final class BadgeRendererTests: XCTestCase {
    func test_produces_square_template_image_of_requested_size() {
        let image = BadgeRenderer.image(forNumber: 4, size: 18)
        XCTAssertEqual(image.size.width, 18, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 18, accuracy: 0.5)
        XCTAssertTrue(image.isTemplate)
    }

    func test_handles_multi_digit_numbers() {
        let image = BadgeRenderer.image(forNumber: 12, size: 18)
        XCTAssertEqual(image.size.width, 18, accuracy: 0.5)
    }

    func test_handles_three_digit_numbers_without_changing_image_size() {
        let image = BadgeRenderer.image(forNumber: 100, size: 18)
        XCTAssertEqual(image.size.width, 18, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 18, accuracy: 0.5)
    }
}
