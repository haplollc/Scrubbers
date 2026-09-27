//
//  ScrubberTelemetry.swift
//  Scrubbers
//
//  A log of every detent tick, stamped on the media clock. Simulator screen
//  recordings are silent, so a demo can play a click for each logged tick
//  in post, on the frame the mark actually passed.
//

import QuartzCore

@_spi(Demo)
@MainActor
public final class ScrubberTelemetry {
    public static let shared = ScrubberTelemetry()

    public struct Tick: Sendable {
        /// `CACurrentMediaTime()` when the mark changed.
        public let time: TimeInterval
        /// The mark the control moved onto.
        public let mark: Int
        public let kind: Kind

        public enum Kind: Int, Sendable {
            /// A detent tick.
            case tick = 1
            /// A firmer knock at an end.
            case knock = 2
            /// A celebration: the emoji's burst on release.
            case burst = 3
        }
    }

    /// Ticks are only kept while this is on.
    public var isRecording = false
    public private(set) var ticks: [Tick] = []
    /// Called for every tick while recording.
    public var onTick: ((Tick) -> Void)?

    public func reset() { ticks.removeAll() }

    /// Logs a haptic (or a burst) as it fires.
    func record(mark: Int, kind: Tick.Kind = .tick) {
        guard isRecording else { return }
        let tick = Tick(time: CACurrentMediaTime(), mark: mark, kind: kind)
        ticks.append(tick)
        onTick?(tick)
    }
}
