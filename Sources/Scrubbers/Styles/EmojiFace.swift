//
//  EmojiFace.swift
//  Scrubbers
//
//  The emoji is the thumb, and it grows with the value: small at the low
//  end, big at the high. It tips with the drag, and when you let go a
//  handful of little copies of it pop out and float away. After Instagram's
//  emoji slider sticker.
//

import SwiftUI

struct EmojiFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext
    let emoji: String

    nonisolated static let height: CGFloat = 100
    nonisolated static let inset: CGFloat = 24

    /// The emoji is drawn at its largest and scaled down, so it stays sharp.
    private static let drawnSize: CGFloat = 64

    @State private var bursts: [Burst] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Burst: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
    }

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let size = context.size
        let lift = CGFloat(motion.lift)
        let track = size.width - Self.inset * 2
        let x = Self.inset + track * CGFloat(motion.fraction)
        let trackY = size.height - 26
        let scale = 0.42 + 0.58 * CGFloat(motion.fraction)
        let tilt = min(max(motion.velocity * 12, -22), 22)

        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(.foreground.opacity(0.1))
                .frame(width: size.width - 16, height: 9)
                .position(x: size.width / 2, y: trackY)
            // The fill brightens toward the thumb.
            Capsule()
                .fill(.tint)
                .overlay {
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .clipShape(Capsule())
                }
                .frame(width: max(x - 8, 9), height: 9)
                .position(x: 8 + max(x - 8, 9) / 2, y: trackY)

            ForEach(bursts) { burst in
                EmojiBurst(emoji: emoji, size: burst.size) {
                    bursts.removeAll { $0.id == burst.id }
                }
                .position(x: burst.x, y: trackY)
            }

            Text(emoji)
                .font(.system(size: Self.drawnSize))
                .fixedSize()
                .scaleEffect(scale * (1 + 0.12 * lift), anchor: .center)
                .rotationEffect(.degrees(tilt))
                .shadow(color: .black.opacity(0.12 * Double(lift)), radius: 6, y: 4)
                .position(x: x, y: trackY)
        }
        .frame(width: size.width, height: size.height)
        .onChange(of: motion.lift > 0.5) { wasHeld, held in
            if wasHeld, !held, !reduceMotion {
                bursts.append(Burst(x: x, size: Self.drawnSize * scale))
                ScrubberTelemetry.shared.record(mark: Int(motion.fraction * 15), kind: .burst)
            }
        }
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }
}

/// A handful of small copies of the emoji that fan out upward and fade.
private struct EmojiBurst: View {
    let emoji: String
    let size: CGFloat
    let done: () -> Void

    @State private var progress: CGFloat = 0
    /// Scattered once, when the burst appears.
    @State private var pieces: [(angle: Double, distance: CGFloat, scale: CGFloat, spin: Double)] = (0..<7).map { i in
        let spread = Double(i) / 6
        return (angle: -150 + 120 * spread + Double.random(in: -8...8),
                distance: CGFloat.random(in: 46...78),
                scale: CGFloat.random(in: 0.22...0.36),
                spin: Double.random(in: -40...40))
    }

    var body: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                let piece = pieces[i]
                let radians = piece.angle * .pi / 180
                Text(emoji)
                    .font(.system(size: 64))
                    .fixedSize()
                    .scaleEffect(piece.scale * (0.6 + 0.4 * progress) * size / 64)
                    .rotationEffect(.degrees(piece.spin * Double(progress)))
                    .offset(x: cos(radians) * piece.distance * progress,
                            y: sin(radians) * piece.distance * progress - 14 * progress * progress)
                    .opacity(Double(1 - progress * progress))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(Animation.easeOut(duration: 0.9).paced) { progress = 1 } completion: { done() }
        }
    }
}

extension EnvironmentValues {
    @Entry var scrubberEmoji: String = "😍"
}

extension View {
    /// Sets the emoji the `.emoji` style uses as its thumb. The default is
    /// the heart-eyes face, as on Instagram's sticker.
    public func scrubberEmoji(_ emoji: String) -> some View {
        environment(\.scrubberEmoji, emoji)
    }
}
