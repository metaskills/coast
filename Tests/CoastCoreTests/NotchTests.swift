import XCTest
@testable import CoastCore

final class NotchTests: XCTestCase {
    func testSmallDeltaIsRaisedToTheFloor() {
        XCTAssertEqual(Notch.distance(1, speed: 1, reverse: false), Notch.minimum)
        XCTAssertEqual(Notch.distance(-1, speed: 1, reverse: false), -Notch.minimum)
    }

    func testFastSpinsKeepTheirDistance() {
        XCTAssertEqual(Notch.distance(120, speed: 1, reverse: false), 120)
    }

    func testSpeedMultiplies() {
        XCTAssertEqual(Notch.distance(1, speed: 2, reverse: false), Notch.minimum * 2)
    }

    func testReverseFlipsDirection() {
        XCTAssertEqual(Notch.distance(1, speed: 1, reverse: true), -Notch.minimum)
        XCTAssertEqual(Notch.distance(-1, speed: 1, reverse: true), Notch.minimum)
    }

    func testZeroStaysZero() {
        XCTAssertEqual(Notch.distance(0, speed: 3, reverse: true), 0)
    }
}
