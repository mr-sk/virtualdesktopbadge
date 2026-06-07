import XCTest
@testable import VirtualDesktopBadgeCore

final class SpaceTrackerTests: XCTestCase {
    func test_set_updates_current_and_fires_callback() {
        let tracker = SpaceTracker()
        var fired: [Int] = []
        tracker.onChange = { fired.append($0) }

        tracker.set(3)
        XCTAssertEqual(tracker.current, 3)
        XCTAssertEqual(fired, [3])
    }

    func test_set_same_value_does_not_fire_again() {
        let tracker = SpaceTracker()
        var count = 0
        tracker.onChange = { _ in count += 1 }

        tracker.set(2)
        tracker.set(2)
        XCTAssertEqual(count, 1)
    }

    func test_set_different_values_fires_each_time() {
        let tracker = SpaceTracker()
        var fired: [Int] = []
        tracker.onChange = { fired.append($0) }

        tracker.set(1)
        tracker.set(2)
        tracker.set(1)
        XCTAssertEqual(fired, [1, 2, 1])
    }
}
