//
//  ScrubberMotion.swift
//  Scrubbers
//
//  How a finger becomes a position, and how a position comes to rest. Each
//  style picks one mapping and one release.
//

import SwiftUI

/// How a touch turns into a position along the control.
enum ScrubberMapping {
    /// The finger's position is the value: the control jumps to where you
    /// touch. The insets are the dead margins at each end of the width.
    case absolute(leading: CGFloat, trailing: CGFloat)

    static func absolute(inset: CGFloat) -> ScrubberMapping {
        .absolute(leading: inset, trailing: inset)
    }
    /// The finger's travel moves the value: touch anywhere and drag. A sweep
    /// of `pointsPerRange` points covers the whole range; `inverted` is for
    /// a scale you drag under a fixed needle, where dragging left brings
    /// higher values in.
    case relative(pointsPerRange: CGFloat, inverted: Bool)
    /// The finger's angle around `center` turns the value, a full range per
    /// `sweep` radians, clockwise.
    case angular(center: CGPoint, sweep: Double)
}

/// What a control does when the finger lifts.
enum ScrubberRelease {
    /// Springs to the nearest detent.
    case settle
    /// Coasts on the finger's speed, then settles on a detent, like a
    /// picker wheel.
    case coast
}

enum ScrubberMotion {
    /// The spring a released control settles with (the eras ruler's).
    static let settle = Animation.spring(response: 0.34, dampingFraction: 0.82)

    /// How far a flick carries: the finger's speed times this many seconds,
    /// about what a scroll view's normal deceleration gives.
    static let coastProjection = 0.32

    /// Apple's rubber band: the further past the end you pull, the less each
    /// extra point stretches, approaching `dimension` but never reaching it.
    static func rubberBand(_ offset: Double, dimension: Double, coefficient: Double = 0.55) -> Double {
        guard dimension > 0 else { return 0 }
        let sign: Double = offset < 0 ? -1 : 1
        let x = abs(offset)
        return sign * (1 - 1 / (x * coefficient / dimension + 1)) * dimension
    }
}
