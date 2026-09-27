//
//  ScaleTests.swift
//  ScrubbersTests
//
//  The value math every style shares: fractions, detents, snapping and the
//  rubber band. Self-contained arithmetic, so it gets plain unit tests; the
//  controls themselves are exercised on iPhone by the demo app's UI tests.
//

import Testing
@testable import Scrubbers

struct ScaleTests {

    @Test func continuousRangeMapsLinearly() {
        let scale = ScrubberScale(range: 40...120, step: nil)
        #expect(scale.fraction(of: 80) == 0.5)
        #expect(scale.value(at: 0.25) == 60)
        #expect(scale.fraction(of: 200) == 1)      // clamped
        #expect(scale.fraction(of: -5) == 0)
        #expect(scale.markCount == 11)
        #expect(!scale.isStepped)
    }

    @Test func steppedRangeSnapsToNearestDetent() {
        let scale = ScrubberScale(range: 0...19, step: 1)
        #expect(scale.markCount == 20)
        #expect(scale.mark(nearest: 0.49 / 19) == 0)
        #expect(scale.mark(nearest: 0.51 / 19) == 1)
        #expect(scale.snapped(9.6 / 19) == 10.0 / 19)
        #expect(scale.value(ofMark: 13) == 13)
    }

    @Test func stepThatDoesNotDivideTheRangeKeepsTheUpperBound() {
        let scale = ScrubberScale(range: 0...10, step: 3)
        #expect(scale.markCount == 5)                 // 0, 3, 6, 9 and 10
        #expect(scale.value(ofMark: 3) == 9)
        #expect(scale.value(ofMark: 4) == 10)
        #expect(scale.mark(nearest: 0.97) == 4)       // 9.7 is nearer 10 than 9
        #expect(scale.mark(nearest: 0.93) == 3)
    }

    @Test func degenerateInputsFallBackToContinuous() {
        #expect(!ScrubberScale(range: 0...1, step: 0).isStepped)
        #expect(!ScrubberScale(range: 5...5, step: 1).isStepped)
        #expect(ScrubberScale(range: 5...5, step: nil).fraction(of: 5) == 0)
    }

    @Test func defaultLabels() {
        #expect(ScrubberScale(range: 0...1, step: nil).defaultLabel(for: 0.5) == 0.5.formatted(.percent.precision(.fractionLength(0))))
        #expect(ScrubberScale(range: 0...10, step: 1).defaultLabel(for: 7) == "7")
    }

    @Test func rubberBandApproachesButNeverReachesItsDimension() {
        let dimension = 100.0
        #expect(ScrubberMotion.rubberBand(0, dimension: dimension) == 0)
        let small = ScrubberMotion.rubberBand(10, dimension: dimension)
        let large = ScrubberMotion.rubberBand(10_000, dimension: dimension)
        #expect(small > 0 && small < 10)              // resists from the first point
        #expect(large < dimension && large > 95)
        #expect(ScrubberMotion.rubberBand(-10, dimension: dimension) == -small)
    }
}
