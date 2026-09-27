//
//  ScrubberOptions.swift
//  Scrubbers
//
//  The modifiers that tune every scrubber below them: how values are
//  labelled, when a stepped value snaps, and whether it ticks.
//

import SwiftUI

/// When a stepped scrubber's value lands on a step.
public enum ScrubberSnapping: Sendable, Hashable {
    /// The value is always on a step, like `Slider(step:)`. The control
    /// still follows your finger smoothly and settles on the step when you
    /// let go.
    case always
    /// The value follows your finger continuously, fractions and all, and
    /// springs to the nearest step on release. Use it when whatever the
    /// scrubber drives can morph between steps.
    case onRelease
}

/// Turns a value into the text a scrubber shows for it. Only ever called on
/// the main actor, from a view body.
struct ScrubberLabeler: @unchecked Sendable {
    let make: @MainActor (Double) -> Text
}

extension EnvironmentValues {
    @Entry var scrubberLabeler: ScrubberLabeler? = nil
    @Entry var scrubberSnapping: ScrubberSnapping = .always
    @Entry var scrubberHaptics: Bool = true
    @Entry var scrubberAnimating: Bool = true
}

extension View {
    /// Sets the text scrubbers show for a value: tick labels, readouts and
    /// the VoiceOver value.
    ///
    /// ```swift
    /// Scrubber(.ruler, value: $year, in: 2007...2026, step: 1)
    ///     .scrubberLabels { Text(String(Int($0))) }
    /// ```
    public func scrubberLabels(_ label: @escaping @MainActor (Double) -> Text) -> some View {
        environment(\.scrubberLabeler, ScrubberLabeler(make: label))
    }

    /// Labels values with a format style.
    ///
    /// ```swift
    /// Scrubber(.dial, value: $gain, in: 0...1)
    ///     .scrubberLabels(format: .percent.precision(.fractionLength(0)))
    /// ```
    public func scrubberLabels<F: FormatStyle>(format: F) -> some View
    where F.FormatInput == Double, F.FormatOutput == String, F: Sendable {
        environment(\.scrubberLabeler, ScrubberLabeler { Text(format.format($0)) })
    }

    /// Chooses when a stepped value lands on its step. The default,
    /// `.always`, keeps the value on a step at all times.
    public func scrubberSnapping(_ snapping: ScrubberSnapping) -> some View {
        environment(\.scrubberSnapping, snapping)
    }

    /// Turns the detent ticks and end knocks on or off. On by default.
    public func scrubberHaptics(_ enabled: Bool) -> some View {
        environment(\.scrubberHaptics, enabled)
    }

    /// Starts or stops the styles that move on their own: the squiggle's
    /// rolling wave (which lies flat while stopped, like a paused player's)
    /// and the mood shape's slow turn. On by default.
    ///
    /// ```swift
    /// Scrubber(.squiggle, value: $position, in: 0...duration)
    ///     .scrubberAnimating(player.isPlaying)
    /// ```
    public func scrubberAnimating(_ animating: Bool) -> some View {
        environment(\.scrubberAnimating, animating)
    }
}
