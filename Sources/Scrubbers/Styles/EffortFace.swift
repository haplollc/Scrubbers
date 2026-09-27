//
//  EffortFace.swift
//  Scrubbers
//
//  A rising row of bars, one per level. The bars up to yours light in a
//  colour that runs from green through yellow and orange to red, the top one
//  hops as you step onto it, and the level and its name sit above: Easy,
//  Moderate, Hard, All Out. After the effort rating in Apple's Fitness app.
//

import SwiftUI

struct EffortFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let height: CGFloat = 150
    nonisolated static let inset: CGFloat = 4

    /// Green to red-pink, easy to all out.
    nonisolated static let palette: [(Double, Double, Double)] = [
        (0.19, 0.80, 0.35), (0.62, 0.86, 0.20), (1.00, 0.84, 0.04),
        (1.00, 0.60, 0.04), (1.00, 0.30, 0.18), (1.00, 0.18, 0.42),
    ]

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    /// Levels: one per detent up to twenty, or ten for a continuous value.
    private var levels: Int {
        context.scale.isStepped ? min(max(context.scale.markCount, 2), 20) : 10
    }

    private var level: Int {
        let scale = context.scale
        if scale.isStepped, scale.markCount <= 20 { return scale.mark(nearest: motion.fraction) }
        return min(Int(motion.fraction * Double(levels)), levels - 1)
    }

    static func color(_ position: Double) -> Color {
        let f = min(max(position, 0), 1) * Double(palette.count - 1)
        let i = min(Int(f), palette.count - 2)
        let t = f - Double(i)
        let a = palette[i], b = palette[i + 1]
        return Color(.sRGB, red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }

    /// Apple's names for the effort bands, on a 10-point scale.
    static func name(_ position: Double) -> String {
        switch position {
        case ..<0.3: return "Easy"
        case ..<0.6: return "Moderate"
        case ..<0.8: return "Hard"
        default: return "All Out"
        }
    }

    var body: some View {
        let levels = levels
        let level = level
        let position = levels > 1 ? Double(level) / Double(levels - 1) : 0
        let tone = Self.color(position)
        let scale = context.scale
        let shown = scale.isStepped && scale.markCount <= 20 ? scale.value(ofMark: level) : Double(level + 1)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                context.label(shown)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: shown))
                ZStack(alignment: .leading) {
                    Text(Self.name(position))
                        .id(Self.name(position))
                        .transition(.push(from: .bottom))
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(tone)
            }
            .animation(.snappy(duration: 0.22).paced, value: level)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<levels, id: \.self) { index in
                    let height = 26 + 58 * CGFloat(index) / CGFloat(max(levels - 1, 1))
                    let lit = index <= level
                    Capsule()
                        .fill(lit ? Self.color(Double(index) / Double(max(levels - 1, 1))) : Color.primary.opacity(0.1))
                        .frame(height: height)
                        .keyframeAnimator(initialValue: CGFloat(1), trigger: level) { bar, stretch in
                            // Only the bar just stepped onto hops.
                            let hop = index == level ? stretch : 1
                            bar.scaleEffect(x: 1 / max(hop, 0.8), y: hop, anchor: .bottom)
                        } keyframes: { _ in
                            let slow = 1 / ScrubberTime.rate
                            SpringKeyframe(1.16, duration: 0.12 * slow, spring: .snappy)
                            SpringKeyframe(0.93, duration: 0.12 * slow, spring: .snappy)
                            SpringKeyframe(1.0, duration: 0.22 * slow, spring: .bouncy)
                        }
                        .animation(.easeOut(duration: 0.18).paced, value: lit)
                }
            }
            .frame(height: 84, alignment: .bottom)
        }
        .padding(.horizontal, Self.inset)
        .frame(width: context.size.width, height: context.size.height, alignment: .bottomLeading)
        // A stepped scale already ticks at each detent, which is each level.
        .sensoryFeedback(.selection, trigger: level) { _, _ in
            context.haptics && !(scale.isStepped && scale.markCount <= 20)
        }
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }
}
