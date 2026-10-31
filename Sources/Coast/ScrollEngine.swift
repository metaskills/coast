import AppKit
import CoastCore

/// Catches mouse wheel events, swallows them, and replays the same distance
/// as a smooth stream of small scrolls, one per display frame.
///
/// Trackpads, Magic Mouse, and free-spinning wheels already send smooth
/// (continuous) events, so they pass through untouched.
final class ScrollEngine: NSObject {
    /// Stamped on every event Coast posts so the tap can ignore its own output.
    private static let marker: Int64 = 0x436F_6173_74 // "Coast"

    private let settings: Settings
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?

    private var glide = Glide()
    private var template: CGEvent?
    private var targetPID: pid_t = 0
    private var link: CADisplayLink?
    private var linkScreen: NSScreen?
    private var lastFrame: CFTimeInterval = 0

    init(settings: Settings) {
        self.settings = settings
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    var isRunning: Bool { tap != nil }

    /// Returns false when macOS has not granted Accessibility access yet.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let engine = Unmanaged<ScrollEngine>.fromOpaque(refcon!).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.tapSource = source
        return true
    }

    func stop() {
        halt()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
    }

    // MARK: - Event tap

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            halt()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            // Clicking stops a glide in progress, like grabbing a moving page.
            halt()
            return Unmanaged.passUnretained(event)
        case .scrollWheel:
            return scroll(event) ? nil : Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Returns true when Coast took over the event.
    private func scroll(_ event: CGEvent) -> Bool {
        guard settings.enabled,
              event.getIntegerValueField(.eventSourceUserData) != Self.marker,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
        else { return false }

        var dy = Self.delta(event, axis: 1)
        var dx = Self.delta(event, axis: 2)
        guard dy != 0 || dx != 0 else { return false }

        // Hold Shift to scroll sideways.
        if event.flags.contains(.maskShift), dy != 0, dx == 0 {
            swap(&dy, &dx)
        }

        let speed = settings.speed, reverse = settings.reverse
        glide.duration = settings.glide
        glide.add(y: Notch.distance(dy, speed: speed, reverse: reverse),
                  x: Notch.distance(dx, speed: speed, reverse: reverse))
        template = event.copy()
        targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        run()
        return true
    }

    private static func delta(_ event: CGEvent, axis: Int) -> Double {
        let point = event.getDoubleValueField(axis == 1 ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventPointDeltaAxis2)
        if point != 0 { return point }
        let fixed = event.getDoubleValueField(axis == 1 ? .scrollWheelEventFixedPtDeltaAxis1 : .scrollWheelEventFixedPtDeltaAxis2)
        if fixed != 0 { return fixed }
        return Double(event.getIntegerValueField(axis == 1 ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2))
    }

    // MARK: - Frame loop

    /// Drive frames from the screen under the pointer so a 120Hz display gets 120 frames.
    private func run() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if link == nil || screen != linkScreen, let screen {
            link?.invalidate()
            let newLink = screen.displayLink(target: self, selector: #selector(frame(_:)))
            newLink.add(to: .main, forMode: .common)
            link = newLink
            linkScreen = screen
            lastFrame = 0
        }
        if link?.isPaused != false {
            lastFrame = 0
            link?.isPaused = false
        }
    }

    @objc private func frame(_ link: CADisplayLink) {
        let dt = lastFrame == 0 ? link.targetTimestamp - link.timestamp : link.timestamp - lastFrame
        lastFrame = link.timestamp
        let d = glide.step(dt: dt)
        if d.y != 0 || d.x != 0 { post(y: d.y, x: d.x) }
        if glide.isIdle { finish() }
    }

    private func post(y: Double, x: Double, phase: Double = 0) {
        guard targetPID != 0, let event = template?.copy() else { return }
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: y)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: x)
        event.setDoubleValueField(.scrollWheelEventIsContinuous, value: 1)
        if phase != 0 { event.setDoubleValueField(.scrollWheelEventScrollPhase, value: phase) }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        // Post straight to the app that was under the pointer, so the glide
        // finishes there even if the pointer moves on.
        event.postToPid(targetPID)
    }

    /// Glide done: Chrome wants an explicit "scroll ended" or it can keep the
    /// scroll latched to one element.
    private func finish() {
        if NSRunningApplication(processIdentifier: targetPID)?.bundleIdentifier == "com.google.Chrome" {
            post(y: 0, x: 0, phase: 4)
        }
        link?.isPaused = true
        template = nil
    }

    /// Stop now and drop anything queued.
    private func halt() {
        glide.reset()
        link?.isPaused = true
        template = nil
    }

    @objc private func screensChanged() {
        halt()
        link?.invalidate()
        link = nil
        linkScreen = nil
    }
}
