//
//  GlassFace.swift
//  Scrubbers
//
//  The iOS 26 slider, turned up: at rest a white pill on a thin track; take
//  hold and the pill swells into a clear lens that magnifies the track
//  beneath it, trails your finger a touch, and stretches the faster you
//  move. Let go and it condenses back into a solid pill. After Apple's
//  Liquid Glass sliders (WWDC25).
//

import SwiftUI

struct GlassFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let height: CGFloat = 52
    /// Half the resting pill, so it can sit on either end of the track.
    nonisolated static let inset: CGFloat = 19

    private static let trackHeight: CGFloat = 6
    private static let pill = CGSize(width: 38, height: 24)
    /// How much bigger the lens is than the pill.
    private static let swell: CGFloat = 0.55
    /// How much the lens magnifies what's under it.
    private static let magnification: CGFloat = 1.5
    /// The band round the lens's edge left to the glass's own refraction.
    private static let rim: CGFloat = 5

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let size = context.size
        let lift = CGFloat(motion.lift)
        let velocity = motion.velocity
        let track = size.width - Self.inset * 2

        // The lens carries a little momentum: it trails a fast finger and
        // catches up when the finger stops.
        let lag = min(max(velocity * 0.018, -0.035), 0.035)
        let x = Self.inset + track * CGFloat(min(max(motion.fraction - lag, 0), 1))
        let speed = CGFloat(min(abs(velocity) * 0.14, 0.3)) * lift
        let grow = 1 + Self.swell * lift
        let lens = CGSize(width: Self.pill.width * grow * (1 + speed),
                          height: Self.pill.height * grow * (1 - speed * 0.45))
        let center = CGPoint(x: x, y: size.height / 2)

        ZStack {
            trackLayer(width: size.width, fillTo: x)

            // The lens: glass that bends the real track at its rim, with the
            // track magnified in its middle, inside the rim. Only there while
            // held: glass costs something every frame it's on screen.
            if lift > 0.001 {
                ZStack {
                    lensGlass(size: lens)
                        .position(center)
                    trackLayer(width: size.width, fillTo: x)
                        .scaleEffect(Self.magnification, anchor: UnitPoint(x: x / max(size.width, 1), y: 0.5))
                        .mask {
                            Capsule()
                                .frame(width: max(lens.width - Self.rim * 2, 0), height: max(lens.height - Self.rim * 2, 0))
                                .blur(radius: 1.5)
                                .position(center)
                        }
                }
                .opacity(Double(lift))
            }

            // The resting pill, which melts into the lens as it lifts.
            Capsule()
                .fill(.white)
                .overlay { Capsule().strokeBorder(.black.opacity(0.05), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1.5)
                .frame(width: lens.width, height: lens.height)
                .position(center)
                .opacity(Double(1 - lift))
        }
        .frame(width: size.width, height: size.height)
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }

    /// The lens's surface. On iOS 26 it is Apple's own clear glass, which
    /// bends the light at its rim; before that, a drawn rim of light.
    @ViewBuilder
    private func lensGlass(size lens: CGSize) -> some View {
        if #available(iOS 26.0, *), Self.nativeGlass {
            Color.clear
                .frame(width: lens.width, height: lens.height)
                .glassEffect(.clear, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        } else {
            Capsule()
                .fill(.white.opacity(0.18))
                .overlay {
                    // A rim of light round the top, fading down the sides.
                    Capsule().strokeBorder(
                        LinearGradient(colors: [.white, .white.opacity(0.2), .white.opacity(0.75)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.6)
                }
                .overlay {
                    // The darker edge where the glass bends the light away,
                    // heaviest underneath: what makes it read on a white page.
                    Capsule().strokeBorder(
                        LinearGradient(colors: [.black.opacity(0.06), .black.opacity(0.2)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.8)
                }
                .frame(width: lens.width, height: lens.height)
                .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
        }
    }

    /// SCRUBBERS_GLASS=drawn shows the drawn lens on iOS 26 too, to check
    /// the fallback.
    static let nativeGlass = ProcessInfo.processInfo.environment["SCRUBBERS_GLASS"] != "drawn"

    /// The thin track, filled with the tint up to `fillTo`.
    private func trackLayer(width: CGFloat, fillTo x: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.foreground.opacity(0.14))
            Capsule()
                .fill(.tint)
                .frame(width: max(x - 2, Self.trackHeight))
        }
        .frame(width: width - 4, height: Self.trackHeight)
        .frame(width: width, height: context.size.height)
    }
}
