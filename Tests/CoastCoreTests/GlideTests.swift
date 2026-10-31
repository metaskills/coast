import XCTest
@testable import CoastCore

final class GlideTests: XCTestCase {
    private func run(_ glide: inout Glide, hz: Double, seconds: Double) -> (y: Double, frames: [Double]) {
        var total = 0.0
        var frames: [Double] = []
        let dt = 1.0 / hz
        for _ in 0..<Int(seconds * hz) {
            let d = glide.step(dt: dt).y
            total += d
            frames.append(d)
        }
        return (total, frames)
    }

    func testDeliversExactDistance() {
        var glide = Glide(duration: 0.35)
        glide.add(y: 100, x: 0)
        let result = run(&glide, hz: 120, seconds: 1)
        XCTAssertEqual(result.y, 100, accuracy: 0.0001)
        XCTAssertTrue(glide.isIdle)
    }

    func testSameFeelAt60And120Hz() {
        var a = Glide(duration: 0.35)
        var b = Glide(duration: 0.35)
        a.add(y: 100, x: 0)
        b.add(y: 100, x: 0)
        // After 0.1s both should have covered the same ground.
        let at60 = run(&a, hz: 60, seconds: 0.1).y
        let at120 = run(&b, hz: 120, seconds: 0.1).y
        XCTAssertEqual(at60, at120, accuracy: 0.01)
    }

    func testEasesInWithoutAJump() {
        var glide = Glide(duration: 0.35)
        glide.add(y: 100, x: 0)
        let frames = run(&glide, hz: 120, seconds: 0.5).frames
        // First frame is small, motion builds, then tapers off.
        XCTAssertLessThan(frames[0], 3)
        let peak = frames.max()!
        XCTAssertGreaterThan(peak, frames[0] * 2)
        XCTAssertTrue(frames.allSatisfy { $0 >= 0 }, "never overshoots backwards")
    }

    func testFinishesWithinDuration() {
        var glide = Glide(duration: 0.35)
        glide.add(y: 100, x: 0)
        _ = run(&glide, hz: 120, seconds: 0.45)
        XCTAssertTrue(glide.isIdle)
    }

    func testNotchesStackInTheSameDirection() {
        var glide = Glide(duration: 0.35)
        glide.add(y: 50, x: 0)
        _ = glide.step(dt: 1.0 / 120)
        glide.add(y: 50, x: 0)
        var total = 0.0
        while !glide.isIdle { total += glide.step(dt: 1.0 / 120).y }
        XCTAssertGreaterThan(total, 95)
    }

    func testReversingTurnsAroundImmediately() {
        var glide = Glide(duration: 0.35)
        glide.add(y: 100, x: 0)
        for _ in 0..<5 { _ = glide.step(dt: 1.0 / 120) }
        glide.add(y: -40, x: 0)
        XCTAssertEqual(glide.remaining.y, -40, accuracy: 0.0001)
        var total = 0.0
        while !glide.isIdle { total += glide.step(dt: 1.0 / 120).y }
        XCTAssertEqual(total, -40, accuracy: 0.0001)
    }

    func testAxesAreIndependent() {
        var glide = Glide(duration: 0.35)
        glide.add(y: 0, x: 30)
        var y = 0.0, x = 0.0
        while !glide.isIdle {
            let d = glide.step(dt: 1.0 / 120)
            y += d.y
            x += d.x
        }
        XCTAssertEqual(y, 0)
        XCTAssertEqual(x, 30, accuracy: 0.0001)
    }

    func testResetStopsDead() {
        var glide = Glide()
        glide.add(y: 100, x: 0)
        _ = glide.step(dt: 1.0 / 120)
        glide.reset()
        XCTAssertTrue(glide.isIdle)
        XCTAssertEqual(glide.step(dt: 1.0 / 120).y, 0)
    }
}
