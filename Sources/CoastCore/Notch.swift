import Foundation

/// How far one wheel event should scroll, in points.
public enum Notch {
    /// macOS sends tiny deltas for a single slow click of the wheel. Raising
    /// them to this floor makes every click move a consistent amount, while
    /// fast spins (which macOS already accelerates) keep their extra distance.
    public static let minimum = 33.6

    public static func distance(_ delta: Double, speed: Double, reverse: Bool) -> Double {
        guard delta != 0 else { return 0 }
        let sign: Double = (delta > 0) != reverse ? 1 : -1
        return sign * max(abs(delta), minimum) * speed
    }
}
