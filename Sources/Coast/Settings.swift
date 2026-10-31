import Foundation

/// The four things you can change. Stored in UserDefaults under com.metaskills.coast.
final class Settings {
    static let speedRange = 1.0...6.0
    static let glideRange = 0.15...0.8

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.reverse: true,
            Key.speed: 2.7,
            Key.glide: 0.35,
        ])
    }

    /// Smooth the mouse wheel at all.
    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Flip wheel direction. On by default so a mouse scrolls the classic way
    /// while the trackpad keeps macOS natural scrolling.
    var reverse: Bool {
        get { defaults.bool(forKey: Key.reverse) }
        set { defaults.set(newValue, forKey: Key.reverse) }
    }

    /// Multiplier on distance per wheel click.
    var speed: Double {
        get { defaults.double(forKey: Key.speed).clamped(to: Self.speedRange) }
        set { defaults.set(newValue.clamped(to: Self.speedRange), forKey: Key.speed) }
    }

    /// Seconds a single click takes to settle.
    var glide: Double {
        get { defaults.double(forKey: Key.glide).clamped(to: Self.glideRange) }
        set { defaults.set(newValue.clamped(to: Self.glideRange), forKey: Key.glide) }
    }

    private enum Key {
        static let enabled = "enabled"
        static let reverse = "reverse"
        static let speed = "speed"
        static let glide = "glide"
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
