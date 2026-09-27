//
//  ScrubberScale.swift
//  Scrubbers
//
//  The value side of a scrubber: where a value sits along the control (its
//  fraction, 0 at the lower bound and 1 at the upper) and where the detents
//  are. Every style draws from the same scale, so they all snap, tick and
//  report the same values for the same range and step.
//

import Foundation

struct ScrubberScale: Equatable, Sendable {
    let lower: Double
    let upper: Double
    /// Distance between detents in value units, or `nil` for a continuous
    /// control.
    let step: Double?

    init(range: ClosedRange<Double>, step: Double?) {
        lower = range.lowerBound
        upper = range.upperBound
        if let step, step > 0, step.isFinite, range.upperBound > range.lowerBound {
            self.step = step
        } else {
            self.step = nil
        }
    }

    var span: Double { max(upper - lower, .leastNonzeroMagnitude) }
    var isStepped: Bool { step != nil }

    /// Whole steps that fit in the range.
    private var fullSteps: Int {
        guard let step else { return 0 }
        return max(Int((span / step + 1e-9).rounded(.down)), 1)
    }

    /// A step that does not divide the range leaves a short last interval,
    /// so the upper bound is always a detent too.
    private var hasTail: Bool {
        guard let step else { return false }
        return span - Double(fullSteps) * step > step * 1e-6
    }

    /// Marks along the control: the detents of a stepped control, or ten
    /// even intervals of a continuous one. Styles draw them; the haptic tick
    /// lands on each one.
    var markCount: Int {
        isStepped ? fullSteps + 1 + (hasTail ? 1 : 0) : 11
    }

    func fraction(of value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max((value - lower) / span, 0), 1)
    }

    func value(at fraction: Double) -> Double {
        lower + min(max(fraction, 0), 1) * span
    }

    /// Where mark `index` sits, as a fraction of the control.
    func fraction(ofMark index: Int) -> Double {
        guard let step else { return Double(index) / 10 }
        return index <= fullSteps ? min(Double(index) * step / span, 1) : 1
    }

    /// The value at mark `index`.
    func value(ofMark index: Int) -> Double {
        guard let step else { return value(at: fraction(ofMark: index)) }
        return index <= fullSteps ? lower + Double(index) * step : upper
    }

    /// The mark nearest a fraction.
    func mark(nearest fraction: Double) -> Int {
        let f = min(max(fraction, 0), 1)
        guard let step else { return Int((f * 10).rounded()) }
        let offset = f * span
        let index = min(max(Int((offset / step).rounded()), 0), fullSteps)
        if hasTail, index == fullSteps, abs(offset - span) < abs(offset - Double(fullSteps) * step) {
            return fullSteps + 1
        }
        return index
    }

    /// A fraction moved onto its nearest detent. Continuous controls are
    /// left where they are.
    func snapped(_ fraction: Double) -> Double {
        guard isStepped else { return min(max(fraction, 0), 1) }
        return self.fraction(ofMark: mark(nearest: fraction))
    }

    /// Default label text: whole numbers plainly, fractions to two places,
    /// and a 0...1 continuous range as a percentage.
    func defaultLabel(for value: Double) -> String {
        if !isStepped, lower == 0, upper == 1 {
            return value.formatted(.percent.precision(.fractionLength(0)))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
