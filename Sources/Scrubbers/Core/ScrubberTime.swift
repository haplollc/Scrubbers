//
//  ScrubberTime.swift
//  Scrubbers
//
//  One clock rate for everything that moves: springs, glides, the live
//  clock, the jelly's physics, a scripted finger. At the default of 1 it is
//  real time. A demo recording on a busy machine can run everything at a
//  third of the speed, so every frame gets drawn, and speed the video back
//  up afterwards with the tempo intact.
//

import SwiftUI

@_spi(Demo)
public enum ScrubberTime {
    /// How fast scrubber time runs against the wall clock: 1 is real time,
    /// 1/3 plays everything three times slower.
    @MainActor public static var rate: Double = 1
}

extension Animation {
    /// This animation at scrubber time.
    @MainActor var paced: Animation {
        ScrubberTime.rate == 1 ? self : speed(ScrubberTime.rate)
    }
}
