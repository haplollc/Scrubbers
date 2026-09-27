//
//  SquiggleFace.swift
//  Scrubbers
//
//  The squiggle: the filled part of the track is a wave that keeps rolling
//  toward the handle, the rest a flat line. Take hold of it and the wave
//  lies down flat so you can place it exactly; let go and it swells back.
//  After Android 13's media seek bar and Material 3 Expressive's wavy
//  slider.
//

import SwiftUI

struct SquiggleFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let height: CGFloat = 44
    /// The handle's half-width plus breathing room at each end.
    nonisolated static let inset: CGFloat = 10


    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    @Environment(\.scrubberAnimating) private var animating

    var body: some View {
        SquiggleTrack(fraction: CGFloat(motion.fraction), lift: CGFloat(motion.lift), swell: animating ? 1 : 0)
            // Paused, the wave lies down flat, as Android's does when the
            // music stops; playing again, it swells back.
            .animation(.easeInOut(duration: 0.6).paced, value: animating)
            .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }
}

private struct SquiggleTrack: View, Animatable {
    let fraction: CGFloat
    let lift: CGFloat
    /// 1 while the wave rolls, 0 when it's paused flat.
    var swell: Double

    nonisolated var animatableData: Double {
        get { swell }
        set { swell = newValue }
    }

    private static let stroke: CGFloat = 4.5
    private static let amplitude: CGFloat = 4
    private static let wavelength: CGFloat = 30
    /// Wavelengths per second the wave rolls toward the handle.
    private static let speed: Double = 0.7
    /// The clear space either side of the handle.
    private static let gap: CGFloat = 7
    private var inset: CGFloat { SquiggleFace.inset }

    var body: some View {
        let fraction = fraction
        let lift = lift
        let swell = CGFloat(swell)
        let inset = inset
        LiveTime(running: swell > 0.001) { seconds in
            Canvas { context, size in
                let midY = size.height / 2
                let track = size.width - inset * 2
                let handleX = inset + track * fraction

                // The rest of the track: a flat line from the handle's gap on.
                let restStart = min(handleX + Self.gap, size.width - inset)
                if restStart < size.width - inset {
                    var rest = Path()
                    rest.move(to: CGPoint(x: restStart, y: midY))
                    rest.addLine(to: CGPoint(x: size.width - inset, y: midY))
                    context.opacity = 0.14
                    context.stroke(rest, with: .foreground,
                                   style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))
                }

                // The filled part: a travelling sine that tapers in at the
                // start and down to nothing just before the handle, so it
                // meets the handle on the centre line. Held, it lies flat.
                let waveEnd = handleX - Self.gap
                if waveEnd > inset {
                    let height = Self.amplitude * (1 - 0.9 * lift) * swell
                    let phase = seconds * Self.speed * 2 * .pi
                    var wave = Path()
                    var x = inset
                    var first = true
                    while true {
                        let fromStart = (x - inset) / (Self.wavelength * 0.5)
                        let toHandle = (waveEnd - x) / Self.wavelength
                        let taper = min(1, fromStart, toHandle).clamped(0, 1)
                        let eased = taper * taper * (3 - 2 * taper)
                        let y = midY + height * eased * CGFloat(sin(Double(x / Self.wavelength) * 2 * .pi - phase))
                        if first { wave.move(to: CGPoint(x: x, y: y)); first = false }
                        else { wave.addLine(to: CGPoint(x: x, y: y)) }
                        if x >= waveEnd { break }
                        x = min(x + 1.5, waveEnd)
                    }
                    context.opacity = 1
                    context.stroke(wave, with: .style(.tint),
                                   style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round, lineJoin: .round))
                }

                // The handle: a rounded bar that stands taller and slimmer
                // under a finger.
                let handleWidth: CGFloat = 5 - 1.5 * lift
                let handleHeight: CGFloat = 26 + 10 * lift
                let handle = CGRect(x: handleX - handleWidth / 2, y: midY - handleHeight / 2,
                                    width: handleWidth, height: handleHeight)
                context.opacity = 1
                context.fill(Path(roundedRect: handle, cornerRadius: handleWidth / 2), with: .style(.tint))
            }
        }
    }
}

extension Comparable {
    func clamped(_ low: Self, _ high: Self) -> Self { min(max(self, low), high) }
}
