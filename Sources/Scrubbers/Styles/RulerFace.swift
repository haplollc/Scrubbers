//
//  RulerFace.swift
//  Scrubbers
//
//  A ruler you scrub instead of a slider you nudge: a row of hairline ticks
//  that swell into a bell around the indicator, with the values set beneath.
//  The position is continuous, so whatever it drives can morph mid-drag; on
//  release it springs to the nearest mark.
//

import SwiftUI

struct RulerFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let tickArea: CGFloat = 56
    nonisolated static let labelArea: CGFloat = 22
    nonisolated static let inset: CGFloat = 14
    nonisolated static var height: CGFloat { tickArea + labelArea }

    /// Aim for a tick every 7 pt or so: close enough to read as a ruler,
    /// far enough apart not to crowd.
    private static let tickPitch: CGFloat = 6.9
    /// A label needs about this much room, gap included.
    private static let labelRoom: CGFloat = 34

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    private var scale: ScrubberScale { context.scale }
    private var track: CGFloat { max(context.size.width - Self.inset * 2, 1) }
    private var nearest: Int { scale.mark(nearest: motion.fraction) }

    /// The spacing of marks, in points (the last interval can be short when
    /// a step doesn't divide the range; the rest are equal).
    private var markPitch: CGFloat {
        scale.markCount > 1 ? track * CGFloat(scale.fraction(ofMark: 1)) : track
    }

    /// Ticks per mark interval, and marks per drawn tick when marks are
    /// packed tighter than a tick.
    private var density: (perMark: Int, markStride: Int) {
        let pitch = max(markPitch, 0.5)
        if pitch >= Self.tickPitch * 1.5 {
            return (max(Int((pitch / Self.tickPitch).rounded()), 1), 1)
        }
        return (1, max(Int((Self.tickPitch / pitch).rounded(.up)), 1))
    }

    /// Every n-th mark is labelled, like the major marks on a ruler.
    private var labelStride: Int {
        let pitch = max(markPitch, 0.5)
        return max(Int((Self.labelRoom / pitch).rounded(.up)), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ticks
                .frame(height: Self.tickArea)
            labels
                .frame(height: Self.labelArea)
        }
        .scrubberFeedback(motion, context)
    }

    /// The ticks are one Canvas rather than a view per tick: the bell is
    /// recomputed for every tick on every frame of a drag, and fifty-odd
    /// views re-laying out at 120 Hz is wasted work next to fifty-odd fills.
    private var ticks: some View {
        let fraction = motion.fraction
        let lifted = motion.lift
        let density = density
        let marks = scale.markCount
        let scale = scale
        return Canvas { context, size in
            let track = size.width - Self.inset * 2
            let indicatorX = Self.inset + track * CGFloat(fraction)
            // The bell's width is a share of the track, so it reads the same
            // on any phone.
            let sigma = track * 0.15
            let rest: CGFloat = 5
            let swell: CGFloat = 30 + 8 * CGFloat(lifted)

            func tick(at x: CGFloat) {
                let distance = (x - indicatorX) / sigma
                let bell = exp(-0.5 * distance * distance)
                let height = rest + swell * bell
                let line = CGRect(x: x - 0.5, y: size.height - height, width: 1, height: height)
                context.opacity = 0.16 + 0.26 * bell
                context.fill(Path(roundedRect: line, cornerRadius: 0.5), with: .foreground)
            }

            var mark = 0
            while mark < marks {
                let from = CGFloat(scale.fraction(ofMark: mark))
                tick(at: Self.inset + track * from)
                let next = mark + density.markStride
                if next < marks, density.perMark > 1 {
                    let to = CGFloat(scale.fraction(ofMark: next))
                    for sub in 1..<density.perMark {
                        tick(at: Self.inset + track * (from + (to - from) * CGFloat(sub) / CGFloat(density.perMark)))
                    }
                }
                if next >= marks, mark != marks - 1 {
                    tick(at: Self.inset + track * CGFloat(scale.fraction(ofMark: marks - 1)))
                }
                mark = next
            }

            let indicatorHeight = rest + swell + 8
            let indicator = CGRect(x: indicatorX - 1.25, y: size.height - indicatorHeight,
                                   width: 2.5, height: indicatorHeight)
            context.opacity = 1
            context.fill(Path(roundedRect: indicator, cornerRadius: 1.25), with: .foreground)
        }
    }

    /// Every other mark (or every n-th, when they're close) is labelled, and
    /// the current one is always called out in bold; its immediate
    /// neighbours step aside so the bold label never collides.
    private var labels: some View {
        let stride = labelStride
        let nearest = nearest
        let candidates: [Int] = scale.markCount <= 80
            ? Array(0..<scale.markCount)
            : Array(Set(Swift.stride(from: 0, to: scale.markCount, by: stride)).union([nearest])).sorted()
        return ZStack(alignment: .topLeading) {
            ForEach(candidates, id: \.self) { index in
                label(index, nearest: nearest, stride: stride)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func label(_ index: Int, nearest: Int, stride: Int) -> some View {
        let isCurrent = index == nearest
        let onGrid = index.isMultiple(of: stride)
        let shown = isCurrent || (onGrid && abs(index - nearest) >= stride)
        let x = Self.inset + track * CGFloat(scale.fraction(ofMark: index))
        let font = Font.system(size: 9, weight: isCurrent ? .bold : .regular).monospacedDigit()
        return context.label(mark: index)
            .font(font)
            .foregroundStyle(.foreground)
            .opacity(isCurrent ? 1 : 0.38)
            .fixedSize()
            .position(x: x, y: 13)
            .opacity(shown ? 1 : 0)
            .animation(.easeOut(duration: 0.15).paced, value: shown)
            .animation(.easeOut(duration: 0.15).paced, value: isCurrent)
    }
}
