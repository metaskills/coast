import Foundation

/// Turns wheel notches into a smooth stream of pixel deltas.
///
/// Each notch moves a target. The page follows the target with a critically
/// damped spring, so motion eases in and out with no overshoot and lands
/// exactly on the distance asked for. The spring is solved in closed form,
/// so it feels the same at 60Hz, 120Hz, or with a dropped frame.
public struct Glide {
    /// Seconds for a single notch to finish about 99% of its distance.
    public var duration: Double {
        didSet { duration = min(max(duration, 0.05), 2.0) }
    }

    private var y = Axis()
    private var x = Axis()

    public init(duration: Double = 0.35) {
        self.duration = min(max(duration, 0.05), 2.0)
    }

    /// True when nothing is left to scroll.
    public var isIdle: Bool { y.isIdle && x.isIdle }

    /// Distance still to be delivered, in points.
    public var remaining: (y: Double, x: Double) { (-y.offset, -x.offset) }

    /// Queue more distance. Reversing direction drops the old motion so the
    /// page turns around right away instead of finishing the old glide first.
    public mutating func add(y dy: Double, x dx: Double) {
        y.add(dy)
        x.add(dx)
    }

    /// Advance by `dt` seconds and return the points to scroll this frame.
    public mutating func step(dt: Double) -> (y: Double, x: Double) {
        let omega = Glide.settleFactor / duration
        let dt = min(max(dt, 0), 0.1)
        return (y.step(dt: dt, omega: omega), x.step(dt: dt, omega: omega))
    }

    /// Stop dead and forget any queued distance.
    public mutating func reset() {
        y = Axis()
        x = Axis()
    }

    /// (1 + wt) e^-wt drops to 1% at wt ~= 6.64.
    static let settleFactor = 6.64
}

private struct Axis {
    /// Position minus target. Negative means there is still distance to go.
    var offset = 0.0
    var velocity = 0.0

    var isIdle: Bool { offset == 0 && velocity == 0 }

    mutating func add(_ delta: Double) {
        guard delta != 0 else { return }
        let goingTheOtherWay = (delta > 0 && offset > 0) || (delta < 0 && offset < 0)
            || (delta > 0 && velocity < 0) || (delta < 0 && velocity > 0)
        if goingTheOtherWay {
            offset = 0
            velocity = 0
        }
        offset -= delta
    }

    mutating func step(dt: Double, omega: Double) -> Double {
        if isIdle { return 0 }
        let decay = exp(-omega * dt)
        let k = velocity + omega * offset
        let newOffset = (offset + k * dt) * decay
        let newVelocity = (velocity - omega * k * dt) * decay
        // Close enough: deliver the last sliver so the total distance is exact.
        if abs(newOffset) < 0.25 && abs(newVelocity) < 8 {
            let last = -offset
            offset = 0
            velocity = 0
            return last
        }
        let moved = newOffset - offset
        offset = newOffset
        velocity = newVelocity
        return moved
    }
}
