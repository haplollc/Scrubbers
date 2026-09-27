//
//  ScrubberPuppet.swift
//  Scrubbers
//
//  A scripted finger. It drives a scrubber through the same code path as a
//  real touch (press, drag, overdrag, flick, release), so every grab state,
//  stretch and swing plays exactly as it would under a thumb. Used for demo
//  recordings and onboarding walkthroughs.
//
//      @_spi(Demo) import Scrubbers
//
//      let finger = ScrubberPuppet()
//      Scrubber(.elastic, value: $volume).scrubberPuppet(finger)
//      ...
//      await finger.scrub(to: 0.8, over: 1.2)
//

import SwiftUI

@_spi(Demo)
@MainActor
@Observable
public final class ScrubberPuppet {

    /// One event from the scripted finger. `fraction` is where the finger
    /// is, expressed as the position it asks of the control: 0 is the lower
    /// end and 1 the upper, and values past either end overdrag.
    public struct Touch: Equatable, Sendable {
        public enum Phase: Sendable { case down, moved, up }
        public var phase: Phase
        public var fraction: Double
        /// On `.up`: how fast the finger was moving, in fractions per
        /// second, for controls that coast.
        public var flick: Double
        /// Makes every event distinct, so two identical moves still arrive.
        var serial: Int
    }

    /// The latest event.
    public var touch: Touch? { events.last }
    /// Where the finger last was, or `nil` when it is up.
    public private(set) var fraction: Double?
    /// Recent events, oldest first. A press and the first move of a glide
    /// arrive in the same turn of the run loop, where SwiftUI only sees the
    /// last change, so the control drains every event it hasn't played yet
    /// rather than reacting to the latest one.
    private(set) var events: [Touch] = []
    private var serial = 0

    public init() {}

    private func send(_ phase: Touch.Phase, _ fraction: Double, flick: Double = 0) {
        serial += 1
        events.append(Touch(phase: phase, fraction: fraction, flick: flick, serial: serial))
        if events.count > 256 { events.removeFirst(events.count - 256) }
        self.fraction = phase == .up ? nil : fraction
    }

    /// The events after `serial`, in order.
    func events(after serial: Int) -> ArraySlice<Touch> {
        guard let first = events.firstIndex(where: { $0.serial > serial }) else { return [] }
        return events[first...]
    }

    /// Puts the finger down at `fraction` (a control that tracks the finger's
    /// position jumps there; one that tracks its travel stays put).
    public func press(at fraction: Double) { send(.down, fraction) }

    /// Moves the finger, still down, to `fraction`.
    public func move(to fraction: Double) { send(.moved, fraction) }

    /// Lifts the finger. A non-zero `flick` (fractions per second) lets a
    /// control that coasts carry on past where the finger left it.
    public func release(flick: Double = 0) {
        send(.up, fraction ?? 0, flick: flick)
    }

    /// The pace of a scripted move.
    public enum Curve: Sendable {
        case linear, easeIn, easeOut, easeInOut

        func callAsFunction(_ x: Double) -> Double {
            switch self {
            case .linear: return x
            case .easeIn: return x * x * x
            case .easeOut: return 1 - pow(1 - x, 3)
            case .easeInOut: return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
            }
        }
    }

    /// Glides the finger (which must be down) to `fraction`, stepping by the
    /// clock so it lands on time however long each frame takes. Returns
    /// false if the task was cancelled.
    @discardableResult
    public func glide(to target: Double, over seconds: Double, curve: Curve = .easeInOut) async -> Bool {
        let from = fraction ?? target
        let clock = ContinuousClock()
        let start = clock.now
        let span = seconds / ScrubberTime.rate
        while true {
            let elapsed = (clock.now - start) / .seconds(1)
            let x = span > 0 ? min(elapsed / span, 1) : 1
            move(to: from + (target - from) * curve(x))
            if x >= 1 { return !Task.isCancelled }
            try? await Task.sleep(for: .seconds(1.0 / 120))
            if Task.isCancelled { return false }
        }
    }

    /// Holds still for a moment. Returns false if the task was cancelled.
    @discardableResult
    public func hold(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds / ScrubberTime.rate))
        return !Task.isCancelled
    }

    /// One whole gesture: press at `from` (or where the control is), glide to
    /// `to`, pause, and lift.
    @discardableResult
    public func scrub(from start: Double? = nil, to target: Double, over seconds: Double,
                      curve: Curve = .easeInOut, flick: Double = 0, settle: Double = 0.05) async -> Bool {
        press(at: start ?? target)
        guard await hold(0.06) else { release(); return false }
        guard await glide(to: target, over: seconds, curve: curve) else { release(); return false }
        if settle > 0 { guard await hold(settle) else { release(); return false } }
        release(flick: flick)
        return !Task.isCancelled
    }
}

extension EnvironmentValues {
    @Entry var scrubberPuppet: ScrubberPuppet? = nil
}

extension View {
    /// Hands the scrubbers below to a scripted finger.
    @_spi(Demo)
    public func scrubberPuppet(_ puppet: ScrubberPuppet?) -> some View {
        environment(\.scrubberPuppet, puppet)
    }
}
