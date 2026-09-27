//
//  ScrubberStyle.swift
//  Scrubbers
//

import SwiftUI

/// The looks a ``Scrubber`` can take. Each is its own control, with its own
/// feel under the finger, not a skin on one slider.
///
/// ```swift
/// Scrubber(.jelly, value: $value)
/// ```
public enum ScrubberStyle: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    /// Hairline ticks that swell into a bell around the indicator, with the
    /// values set beneath. The ruler from iOS Eras.
    case ruler
    /// A white pill that swells into a clear lens while you hold it,
    /// magnifying the track beneath and stretching as it moves.
    case glass
    /// A strip of jelly in a slot. Push it faster than it can shorten and it
    /// buckles into a hump that wobbles flat; pull it and it stretches thin.
    case jelly
    /// A track that thickens under your finger and stretches when you pull
    /// past an end, then snaps back with a wobble.
    case elastic
    /// A fat bar with the value in a white bead. Touch it and the bead rises
    /// out of the bar on a gooey neck; let go and it drips back in.
    case fluid
    /// The filled part is a wave that rolls toward the handle and lies flat
    /// while you hold it.
    case squiggle
    /// A round face ringed by ticks, turned by dragging round the ring. The
    /// face floods blue low in the range and orange high in it.
    case thermostat
    /// A round thumb carrying a tag with the value. The tag leans back as the
    /// thumb moves and swings upright when it stops.
    case swing
    /// A shape that morphs from a spiky violet burst through a blue circle to
    /// an orange flower as you drag, with a word for where you are.
    case mood
    /// A tape measure you drag under a fixed needle. Flick it and it coasts,
    /// ticking past each mark, then settles on one.
    case tape
    /// A rising row of bars, one per level, lit green to red up to yours; the
    /// top bar hops as you step onto it.
    case effort
    /// The emoji is the thumb and grows with the value; let go and little
    /// copies of it pop out and float away.
    case emoji

    public var id: String { rawValue }

    /// The style's display name, such as "Jelly".
    public var title: String {
        switch self {
        case .ruler: return "Ruler"
        case .glass: return "Glass"
        case .jelly: return "Jelly"
        case .elastic: return "Elastic"
        case .fluid: return "Fluid"
        case .squiggle: return "Squiggle"
        case .thermostat: return "Thermostat"
        case .swing: return "Swing"
        case .mood: return "Mood"
        case .tape: return "Tape"
        case .effort: return "Effort"
        case .emoji: return "Emoji"
        }
    }

    /// One line on what it does.
    public var summary: String {
        switch self {
        case .ruler: return "Ticks swell into a bell around the indicator"
        case .glass: return "The thumb turns into a lens while held"
        case .jelly: return "Buckles into a wobbling hump when you push it"
        case .elastic: return "Stretches past its ends and snaps back"
        case .fluid: return "The value pops out on a gooey neck"
        case .squiggle: return "A wave that flattens while you hold it"
        case .thermostat: return "A dial that floods warm or cool as you turn it"
        case .swing: return "A value tag that leans and swings with weight"
        case .mood: return "Drag a feeling from spiky to round to blooming"
        case .tape: return "A scale that coasts under a fixed needle"
        case .effort: return "Stepped bars that hop as you climb"
        case .emoji: return "An emoji thumb that grows with the value"
        }
    }

    /// Where the design comes from.
    public var inspiration: String {
        switch self {
        case .ruler: return "iOS Eras, after @colderoshay's “life of a button”"
        case .glass: return "Apple's Liquid Glass sliders, iOS 26"
        case .jelly: return "Voicu Apostol's Jelly Slider and Software Mansion's real-time port"
        case .elastic: return "Apple's volume sliders and BuildUI's Elastic Slider"
        case .fluid: return "Virgil Pana's Fluid Slider, open-sourced by Ramotion"
        case .squiggle: return "Android 13's seek bar and Material 3 Expressive"
        case .thermostat: return "The Nest Learning Thermostat"
        case .swing: return "The keyframers' Diamond Slider and Temani Afif's CSS tooltip"
        case .mood: return "Apple's State of Mind logging in Health"
        case .tape: return "Health-app weight pickers and the Photos adjustment ruler"
        case .effort: return "The effort rating in Apple's Fitness app"
        case .emoji: return "Instagram's emoji slider sticker"
        }
    }
}

extension ScrubberStyle {
    /// How a style is laid out and how it moves.
    struct Spec {
        /// A fixed width, or `nil` to fill the width offered.
        var width: CGFloat?
        var height: CGFloat
        var mapping: (CGSize) -> ScrubberMapping
        var release: ScrubberRelease = .settle
        /// Whether pulling past an end stretches the control.
        var stretches = false
        /// How many points of finger travel cover the whole range: the
        /// scale overdrag is measured in.
        var pointsPerRange: (CGSize) -> CGFloat = { $0.width }
        /// The length the rubber band approaches but never reaches.
        var bandDimension: (CGSize) -> CGFloat = { $0.width * 0.5 }
        var liftIn: Animation = .easeOut(duration: 0.18)
        var liftOut: Animation = .easeOut(duration: 0.3)
        var settle: Animation = ScrubberMotion.settle
        /// How a stretch springs back.
        var recoil: Animation = .spring(response: 0.42, dampingFraction: 0.5)
        /// How the smoothed speed returns to zero when the finger stops or
        /// lifts: a looser spring swings.
        var swingBack: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    }

    /// - Parameters:
    ///   - scale: The range and step, for styles whose travel depends on it.
    ///   - icons: Whether end icons are showing, for the styles that can
    ///     carry them.
    func spec(scale: ScrubberScale, icons: Bool = false) -> Spec {
        let press = Animation.spring(response: 0.3, dampingFraction: 0.8)
        let letGo = Animation.spring(response: 0.4, dampingFraction: 0.8)
        switch self {
        case .ruler:
            return Spec(height: RulerFace.height, mapping: { _ in .absolute(inset: RulerFace.inset) })
        case .glass:
            return Spec(height: GlassFace.height, mapping: { _ in .absolute(inset: GlassFace.inset) },
                        liftIn: .spring(response: 0.32, dampingFraction: 0.62),
                        liftOut: .spring(response: 0.36, dampingFraction: 0.7),
                        swingBack: .spring(response: 0.34, dampingFraction: 0.55))
        case .jelly:
            return Spec(height: JellyFace.height,
                        mapping: { _ in .absolute(leading: JellyFace.inset + JellyFace.minimumLength, trailing: JellyFace.inset) },
                        liftIn: press, liftOut: letGo)
        case .elastic:
            return Spec(height: ElasticFace.height,
                        mapping: { .relative(pointsPerRange: ElasticFace.trackLength($0.width, hasIcons: icons), inverted: false) },
                        stretches: true,
                        pointsPerRange: { ElasticFace.trackLength($0.width, hasIcons: icons) },
                        bandDimension: { _ in ElasticFace.maxStretch },
                        liftIn: .spring(response: 0.28, dampingFraction: 0.7),
                        liftOut: .spring(response: 0.4, dampingFraction: 0.75),
                        recoil: .spring(response: 0.46, dampingFraction: 0.42))
        case .fluid:
            return Spec(height: FluidFace.height, mapping: { _ in .absolute(inset: FluidFace.inset) },
                        liftIn: .spring(response: 0.36, dampingFraction: 0.5),
                        liftOut: .spring(response: 0.28, dampingFraction: 0.72),
                        swingBack: .spring(response: 0.45, dampingFraction: 0.4))
        case .squiggle:
            return Spec(height: SquiggleFace.height, mapping: { _ in .absolute(inset: SquiggleFace.inset) },
                        liftIn: .spring(response: 0.35, dampingFraction: 0.8),
                        liftOut: .spring(response: 0.7, dampingFraction: 0.55))
        case .thermostat:
            return Spec(height: ThermostatFace.height,
                        mapping: { .angular(center: CGPoint(x: $0.width / 2, y: $0.height / 2), sweep: ThermostatFace.sweep) },
                        liftIn: press, liftOut: letGo)
        case .swing:
            return Spec(height: SwingFace.height, mapping: { _ in .absolute(inset: SwingFace.inset) },
                        liftIn: .spring(response: 0.3, dampingFraction: 0.55),
                        liftOut: .spring(response: 0.35, dampingFraction: 0.7),
                        swingBack: .spring(response: 0.62, dampingFraction: 0.28))
        case .mood:
            return Spec(height: MoodFace.height, mapping: { _ in .absolute(inset: MoodFace.inset) },
                        liftIn: .spring(response: 0.35, dampingFraction: 0.7),
                        liftOut: .spring(response: 0.45, dampingFraction: 0.7))
        case .tape:
            return Spec(height: TapeFace.height,
                        mapping: { _ in .relative(pointsPerRange: TapeFace.length(scale), inverted: true) },
                        release: .coast,
                        liftIn: press,
                        liftOut: .spring(response: 0.45, dampingFraction: 0.8))
        case .effort:
            return Spec(height: EffortFace.height, mapping: { _ in .absolute(inset: EffortFace.inset) },
                        liftIn: press, liftOut: letGo)
        case .emoji:
            return Spec(height: EmojiFace.height, mapping: { _ in .absolute(inset: EmojiFace.inset) },
                        liftIn: .spring(response: 0.3, dampingFraction: 0.5),
                        liftOut: .spring(response: 0.42, dampingFraction: 0.45),
                        swingBack: .spring(response: 0.5, dampingFraction: 0.35))
        }
    }
}
