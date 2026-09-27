//
//  ScrubberFace.swift
//  Scrubbers
//
//  What a style is handed to draw one frame. The moving parts travel
//  together as one animatable vector, so a style that conforms to
//  `Animatable` is redrawn at every frame of a settle, a coast or a swing,
//  and its detent ticks land on the frames where the marks actually pass.
//

import SwiftUI

/// The parts of a scrubber that move.
struct ScrubberKinematics: VectorArithmetic, Sendable {
    /// Where the control is, 0 at the lower end and 1 at the upper.
    var fraction: Double = 0
    /// 0 at rest, 1 while a finger is down.
    var lift: Double = 0
    /// Rubber-banded overdrag past an end, in points: negative past the
    /// lower end, positive past the upper.
    var stretch: Double = 0
    /// How fast the control is moving, in fractions per second, smoothed by
    /// a spring so it can swing things.
    var velocity: Double = 0

    static let zero = ScrubberKinematics()

    static func + (a: Self, b: Self) -> Self {
        Self(fraction: a.fraction + b.fraction, lift: a.lift + b.lift,
             stretch: a.stretch + b.stretch, velocity: a.velocity + b.velocity)
    }

    static func - (a: Self, b: Self) -> Self {
        Self(fraction: a.fraction - b.fraction, lift: a.lift - b.lift,
             stretch: a.stretch - b.stretch, velocity: a.velocity - b.velocity)
    }

    mutating func scale(by rhs: Double) {
        fraction *= rhs; lift *= rhs; stretch *= rhs; velocity *= rhs
    }

    var magnitudeSquared: Double {
        fraction * fraction + lift * lift + stretch * stretch + velocity * velocity
    }
}

/// The parts of a scrubber that don't animate.
struct ScrubberContext {
    let scale: ScrubberScale
    let labeler: ScrubberLabeler?
    let haptics: Bool
    let size: CGSize

    @MainActor
    func label(_ value: Double) -> Text {
        labeler?.make(value) ?? Text(scale.defaultLabel(for: value))
    }

    @MainActor
    func label(mark index: Int) -> Text {
        label(scale.value(ofMark: index))
    }
}

extension View {
    /// A light tick each time the control passes a mark: the nearest mark
    /// for a stepped control (so the tick lands as it clicks into the next
    /// detent), each mark crossed for a continuous one. A firmer knock when a
    /// continuous control runs into an end while held.
    ///
    /// `continuousMarks` is how many ticks a continuous control gives across
    /// its range (ten by default).
    func scrubberFeedback(_ motion: ScrubberKinematics, _ context: ScrubberContext,
                          ticksWhenContinuous: Bool = true, continuousMarks: Int = 10) -> some View {
        let scale = context.scale
        let mark = scale.isStepped
            ? scale.mark(nearest: motion.fraction)
            : Int((min(max(motion.fraction, 0), 1) * Double(continuousMarks)).rounded(.down))
        let end = motion.fraction <= 0.0005 ? -1 : (motion.fraction >= 0.9995 ? 1 : 0)
        let tick = context.haptics && (scale.isStepped || ticksWhenContinuous)
        let knock = context.haptics && !scale.isStepped && motion.lift > 0.5
        return self
            .sensoryFeedback(.selection, trigger: mark) { _, _ in tick }
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.75), trigger: end) { _, new in
                knock && new != 0
            }
            .onChange(of: mark) { _, new in
                if tick { ScrubberTelemetry.shared.record(mark: new) }
            }
            .onChange(of: end) { _, new in
                if knock, new != 0 { ScrubberTelemetry.shared.record(mark: new > 0 ? 15 : 0, kind: .knock) }
            }
    }
}
