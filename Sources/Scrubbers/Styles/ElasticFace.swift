//
//  ElasticFace.swift
//  Scrubbers
//
//  The Control Center slider, on a leash: a track that thickens when you
//  take hold of it and stretches when you pull past either end, thinning as
//  it goes, with the icon at that end carried along. Let go and it snaps
//  back with a wobble. After Apple's volume sliders and BuildUI's Elastic
//  Slider.
//

import SwiftUI

struct ElasticFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext
    let icons: ScrubberIcons?

    nonisolated static let height: CGFloat = 52
    nonisolated static let iconSlot: CGFloat = 28
    nonisolated static let gap: CGFloat = 10
    /// How far the track can stretch, approached but never reached.
    nonisolated static let maxStretch: CGFloat = 26

    /// The track's length: the width less the icons, when there are icons.
    nonisolated static func trackLength(_ width: CGFloat, hasIcons: Bool) -> CGFloat {
        max(width - (hasIcons ? (iconSlot + gap) * 2 : 0), 1)
    }

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let width = context.size.width
        let hasIcons = icons != nil
        let track = Self.trackLength(width, hasIcons: hasIcons)
        let stretch = CGFloat(motion.stretch)
        let pull = min(abs(stretch) / Self.maxStretch, 1)

        // Held, the track fattens; stretched, it thins as it lengthens,
        // as if it kept its volume.
        let thickness = (8 + 10 * CGFloat(motion.lift)) * (1 - 0.32 * pull)
        let length = track + abs(stretch)
        // The track grows toward the pull: its far end follows the finger.
        let shift = stretch / 2

        HStack(spacing: Self.gap) {
            if let icons {
                icon(icons.low, pushed: stretch < 0 ? stretch : 0, pull: stretch < 0 ? pull : 0)
            }
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.foreground.opacity(0.12))
                Rectangle()
                    .fill(.tint)
                    .frame(width: length * CGFloat(motion.fraction))
            }
            .frame(width: length, height: thickness)
            .clipShape(Capsule())
            .offset(x: shift)
            .frame(width: track, height: Self.height)
            if let icons {
                icon(icons.high, pushed: stretch > 0 ? stretch : 0, pull: stretch > 0 ? pull : 0)
            }
        }
        .frame(width: width, height: context.size.height)
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }

    /// An end icon rides out with the stretch and swells a little, as if the
    /// track were pressing on it.
    private func icon(_ name: String, pushed: CGFloat, pull: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.foreground.opacity(0.55 + 0.45 * motion.lift))
            .frame(width: Self.iconSlot, height: Self.iconSlot)
            .scaleEffect(1 + 0.22 * pull)
            .offset(x: pushed * 0.72)
    }
}

/// The two icons some styles set at their ends.
struct ScrubberIcons: Sendable, Equatable {
    var low: String
    var high: String
}

extension EnvironmentValues {
    @Entry var scrubberIcons: ScrubberIcons? = nil
}

extension View {
    /// Sets SF Symbols for the low and high ends, for the styles that show
    /// them (`.elastic`).
    ///
    /// ```swift
    /// Scrubber(.elastic, value: $volume)
    ///     .scrubberIcons(low: "speaker.fill", high: "speaker.wave.3.fill")
    /// ```
    public func scrubberIcons(low: String, high: String) -> some View {
        environment(\.scrubberIcons, ScrubberIcons(low: low, high: high))
    }
}
