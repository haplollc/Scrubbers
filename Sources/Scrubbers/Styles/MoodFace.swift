//
//  MoodFace.swift
//  Scrubbers
//
//  You drag the feeling itself: above a gradient track, a layered shape
//  morphs from a spiky violet burst through a calm blue circle to an orange
//  flower, turning slowly, while a word names where you are, from Very
//  Unpleasant to Very Pleasant. After Apple's State of Mind logging in
//  Health.
//

import SwiftUI

struct MoodFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let height: CGFloat = 250
    nonisolated static let inset: CGFloat = 16

    /// Very Unpleasant to Very Pleasant, as Apple colours them.
    nonisolated static let palette: [(Double, Double, Double)] = [
        (0.36, 0.20, 0.80), (0.46, 0.33, 0.96), (0.30, 0.50, 1.00), (0.24, 0.72, 0.98),
        (0.34, 0.80, 0.62), (1.00, 0.76, 0.24), (1.00, 0.53, 0.12),
    ]
    nonisolated static let words = [
        "Very Unpleasant", "Unpleasant", "Slightly Unpleasant", "Neutral",
        "Slightly Pleasant", "Pleasant", "Very Pleasant",
    ]

    @Environment(\.scrubberAnimating) private var animating

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    static func color(at fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1) * Double(palette.count - 1)
        let i = min(Int(f), palette.count - 2)
        let t = f - Double(i)
        let a = palette[i], b = palette[i + 1]
        return Color(.sRGB, red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }

    /// Which of the seven words the fraction falls in.
    static func band(_ fraction: Double) -> Int {
        min(Int(min(max(fraction, 0), 1) * Double(words.count)), words.count - 1)
    }

    var body: some View {
        let size = context.size
        let mood = motion.fraction
        let lift = CGFloat(motion.lift)
        let band = Self.band(mood)
        let track = size.width - Self.inset * 2
        let x = Self.inset + track * CGFloat(mood)

        VStack(spacing: 0) {
            LiveTime(running: animating) { seconds in
                ZStack {
                    // A glow of the mood's colour behind it.
                    Circle()
                        .fill(Self.color(at: mood).opacity(0.35))
                        .frame(width: 120, height: 120)
                        .blur(radius: 30)
                    ForEach(0..<3, id: \.self) { layer in
                        let spin = seconds * [0.16, -0.11, 0.07][layer] + Double(layer) * 0.5
                        MoodShape(mood: mood, spin: spin)
                            .fill(Self.color(at: mood + Double(layer - 1) * 0.06).opacity([0.55, 0.6, 0.9][layer]))
                            .frame(width: [150, 128, 104][layer], height: [150, 128, 104][layer])
                    }
                }
                .scaleEffect(1 + 0.05 * lift)
            }
            .frame(height: 164)

            // Each word pushes the last one out, as Health's do.
            ZStack {
                if context.labeler != nil {
                    context.label(context.scale.value(at: mood))
                } else {
                    Text(Self.words[band])
                        .id(band)
                        .transition(.push(from: .bottom))
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.foreground)
            .animation(.snappy(duration: 0.3).paced, value: band)
            .frame(height: 28)
            .clipped()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: Self.palette.map { Color(.sRGB, red: $0.0, green: $0.1, blue: $0.2) },
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .padding(.horizontal, Self.inset - 6)
                Circle()
                    .fill(.white)
                    .overlay { Circle().strokeBorder(Self.color(at: mood), lineWidth: 2.5) }
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1.5)
                    .frame(width: 28, height: 28)
                    .scaleEffect(1 + 0.12 * lift)
                    .offset(x: x - 14)
            }
            .frame(height: 58)
        }
        .frame(width: size.width, height: size.height)
        .sensoryFeedback(.selection, trigger: band) { _, _ in context.haptics && !context.scale.isStepped }
        .onChange(of: band) { _, new in
            if context.haptics, !context.scale.isStepped { ScrubberTelemetry.shared.record(mark: new * 2) }
        }
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }
}

/// One closed shape whose outline morphs with the mood: 11 sharp spikes at
/// the unpleasant end, a circle in the middle, 7 round petals at the
/// pleasant end.
struct MoodShape: Shape {
    var mood: Double
    var spin: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(mood, spin) }
        set { mood = newValue.first; spin = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        let samples = 288
        for i in 0...samples {
            let phi = Double(i) / Double(samples) * 2 * .pi
            let r = radius * CGFloat(Self.radius(at: phi + spin, mood: mood))
            let point = CGPoint(x: center.x + r * CGFloat(cos(phi)), y: center.y + r * CGFloat(sin(phi)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// The outline's radius at an angle, as a share of the full radius.
    static func radius(at phi: Double, mood: Double) -> Double {
        let m = min(max(mood, 0), 1)
        if m < 0.5 {
            // Spikes: narrow peaks over a smaller body.
            let t = pow(1 - m * 2, 1.2)
            let peaks = pow(abs(cos(11 * phi / 2)), 5)
            return (1 - 0.46 * t) + 0.46 * t * peaks
        } else {
            // Petals: broad lobes parted by narrow notches.
            let t = pow(m * 2 - 1, 1.1)
            let lobes = pow(abs(cos(7 * phi / 2)), 0.55)
            return 1 - 0.3 * t * (1 - lobes)
        }
    }
}
