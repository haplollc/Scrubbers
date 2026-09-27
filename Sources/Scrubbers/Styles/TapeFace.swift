//
//  TapeFace.swift
//  Scrubbers
//
//  A tape measure under a fixed needle: you drag the scale, not a thumb,
//  and a flick sends it coasting until it settles on a mark, ticking past
//  each one. The value sits above the needle in large type and rolls as it
//  changes. After the weight and height pickers of health apps and the
//  Photos app's adjustment ruler.
//

import SwiftUI

struct TapeFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let readoutArea: CGFloat = 50
    nonisolated static let tapeArea: CGFloat = 50
    nonisolated static let labelArea: CGFloat = 22
    nonisolated static var height: CGFloat { readoutArea + tapeArea + labelArea }

    /// Intervals the tape is divided into: one per step, or a hundred for a
    /// continuous value.
    nonisolated static func intervals(_ scale: ScrubberScale) -> Int {
        scale.isStepped ? max(scale.markCount - 1, 1) : 100
    }

    /// Points between minor ticks: 10, or wider when there are few of them,
    /// so a short range still makes a tape worth dragging.
    nonisolated static func pitch(_ scale: ScrubberScale) -> CGFloat {
        let count = intervals(scale)
        return count >= 40 ? 10 : min(max(10, 400 / CGFloat(count)), 44)
    }

    /// The tape's whole length: the distance a finger drags it end to end.
    nonisolated static func length(_ scale: ScrubberScale) -> CGFloat {
        CGFloat(intervals(scale)) * pitch(scale)
    }

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    private var scale: ScrubberScale { context.scale }

    /// Every n-th tick is major and labelled; every half of that, medium.
    private var majorEvery: Int {
        let pitch = Self.pitch(scale)
        for every in [1, 2, 5, 10, 20, 50, 100] where CGFloat(every) * pitch >= 54 {
            return every
        }
        return 100
    }

    var body: some View {
        let intervals = Self.intervals(scale)
        let pitch = Self.pitch(scale)
        let offset = CGFloat(motion.fraction) * CGFloat(intervals) * pitch
        let width = context.size.width
        let majorEvery = majorEvery
        let lift = CGFloat(motion.lift)

        // Labels for the major ticks in view, built here so the canvas only
        // has to place them.
        let first = max(Int(((offset - width / 2) / pitch).rounded(.down)) - 1, 0)
        let last = min(Int(((offset + width / 2) / pitch).rounded(.up)) + 1, intervals)
        let majors = first <= last ? (first...last).filter { $0.isMultiple(of: majorEvery) } : []
        let labels = Dictionary(uniqueKeysWithValues: majors.map { tick in
            (tick, context.label(value(ofTick: tick, intervals: intervals))
                .font(.system(size: 12, weight: .medium).monospacedDigit()))
        })

        VStack(spacing: 0) {
            readout
                .frame(height: Self.readoutArea)
            ZStack(alignment: .top) {
                Canvas { context, size in
                    let center = size.width / 2
                    for tick in first...max(first, last) where tick <= intervals {
                        let x = center + CGFloat(tick) * pitch - offset
                        let major = tick.isMultiple(of: majorEvery)
                        let medium = !major && majorEvery.isMultiple(of: 2) && tick.isMultiple(of: majorEvery / 2)
                        let height: CGFloat = major ? 30 : (medium ? 21 : 14)
                        let line = CGRect(x: x - 0.75, y: Self.tapeArea - height, width: 1.5, height: height)
                        context.opacity = major ? 0.75 : 0.32
                        context.fill(Path(roundedRect: line, cornerRadius: 0.75), with: .foreground)
                        if major, let label = labels[tick] {
                            context.opacity = 0.55
                            context.draw(label, at: CGPoint(x: x, y: Self.tapeArea + 12), anchor: .center)
                        }
                    }
                }
                .frame(height: Self.tapeArea + Self.labelArea)
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.3),
                        .init(color: .black, location: 0.7),
                        .init(color: .clear, location: 1),
                    ], startPoint: .leading, endPoint: .trailing)
                }

                // The needle stands a little taller while the tape is held.
                let needle = 40 + 8 * lift
                Capsule()
                    .fill(.tint)
                    .frame(width: 3.5, height: needle)
                    .offset(y: Self.tapeArea + 3 - needle)
            }
            .frame(height: Self.tapeArea + Self.labelArea)
        }
        .scrubberFeedback(motion, context, continuousMarks: 100)
    }

    private func value(ofTick tick: Int, intervals: Int) -> Double {
        scale.isStepped ? scale.value(ofMark: tick) : scale.value(at: Double(tick) / Double(intervals))
    }

    /// The current value in large type, rolling digit by digit as the mark
    /// under the needle changes.
    private var readout: some View {
        let mark = scale.isStepped
            ? scale.mark(nearest: motion.fraction)
            : Int((motion.fraction * 100).rounded())
        let shown = scale.isStepped ? scale.value(ofMark: mark) : scale.value(at: Double(mark) / 100)
        return context.label(shown)
            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.foreground)
            .contentTransition(.numericText(value: shown))
            .animation(.snappy(duration: 0.22).paced, value: mark)
            .scaleEffect(1 + 0.05 * motion.lift, anchor: .bottom)
    }
}
