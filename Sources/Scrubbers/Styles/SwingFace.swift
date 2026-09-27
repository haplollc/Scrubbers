//
//  SwingFace.swift
//  Scrubbers
//
//  A thin track and a round thumb carrying a tag with the value. The tag has
//  weight: it springs up when you take hold, leans back against the way the
//  thumb is moving, and swings past upright and settles when it stops.
//  After the keyframers' Diamond Slider and Temani Afif's jiggling CSS
//  tooltip.
//

import SwiftUI

struct SwingFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let height: CGFloat = 92
    nonisolated static let inset: CGFloat = 14

    private static let thumb: CGFloat = 26
    /// The steepest the tag leans, in degrees.
    private static let maxLean: Double = 18

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let size = context.size
        let lift = CGFloat(motion.lift)
        let track = size.width - Self.inset * 2
        let x = Self.inset + track * CGFloat(motion.fraction)
        let trackY = size.height - Self.thumb / 2 - 2
        // Leans back against the motion, like a flag on a pole being run.
        let lean = min(max(-motion.velocity * 16, -Self.maxLean), Self.maxLean)

        ZStack(alignment: .topLeading) {
            // Track and fill.
            Capsule()
                .fill(.foreground.opacity(0.1))
                .frame(width: size.width - 8, height: 5)
                .position(x: size.width / 2, y: trackY)
            Capsule()
                .fill(.tint)
                .frame(width: max(x - 4, 5), height: 5)
                .position(x: 4 + max(x - 4, 5) / 2, y: trackY)

            // The tag, pivoting on the point where it meets the thumb.
            tag
                .scaleEffect(0.82 + 0.18 * lift, anchor: .bottom)
                .rotationEffect(.degrees(lean), anchor: .bottom)
                .offset(y: -6 * lift)
                .frame(width: 120, height: 44, alignment: .bottom)
                .position(x: x, y: trackY - Self.thumb / 2 - 4 - 22)

            Circle()
                .fill(.white)
                .overlay { Circle().strokeBorder(.tint, lineWidth: 3) }
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1.5)
                .frame(width: Self.thumb, height: Self.thumb)
                .scaleEffect(1 + 0.1 * lift)
                .position(x: x, y: trackY)
        }
        .frame(width: size.width, height: size.height)
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }

    /// The value on a tinted tag, with a point underneath.
    private var tag: some View {
        let scale = context.scale
        let mark = scale.isStepped ? scale.mark(nearest: motion.fraction) : Int((motion.fraction * 100).rounded())
        let shown = scale.isStepped ? scale.value(ofMark: mark) : scale.value(at: Double(mark) / 100)
        return VStack(spacing: -1) {
            context.label(shown)
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                // The page's own colour, so it reads on any tint, even a white
                // one in dark mode.
                .foregroundStyle(.background)
                .contentTransition(.numericText(value: shown))
                .animation(.snappy(duration: 0.2).paced, value: mark)
                .padding(.horizontal, 11)
                .frame(minWidth: 48, minHeight: 32)
                .background(.tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            TagPoint()
                .fill(.tint)
                .frame(width: 12, height: 6)
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}

/// The downward point under a tag.
private struct TagPoint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.maxY * 0.6))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY * 0.6))
        path.closeSubpath()
        return path
    }
}
