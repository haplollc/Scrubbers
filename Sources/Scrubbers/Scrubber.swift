//
//  Scrubber.swift
//  Scrubbers
//
//  One view, one enum. The view owns the touch: it turns a finger into a
//  position, rubber-bands it past the ends, measures how fast it is moving,
//  snaps it to a detent and lets it coast, then hands the moving parts to
//  whichever style is drawing.
//

import SwiftUI

/// A slider you'll want to touch. Pick a look with ``ScrubberStyle``; every
/// style takes the same value, range and step.
///
/// ```swift
/// @State private var volume = 0.6
///
/// Scrubber(.elastic, value: $volume)
/// Scrubber(.tape, value: $weight, in: 40...120, step: 0.5)
/// Scrubber(.thermostat, value: $temperature, in: 50...90, step: 1)
/// ```
///
/// Every style ticks a light haptic as it passes a detent, reads to
/// VoiceOver as a standard slider, and follows `.tint` and
/// `.foregroundStyle`.
public struct Scrubber: View {

    private let style: ScrubberStyle
    private let value: Binding<Double>
    private let scale: ScrubberScale
    private let onEditingChanged: (Bool) -> Void

    /// - Parameters:
    ///   - style: How the scrubber looks and moves.
    ///   - value: The value it edits.
    ///   - range: The values it covers.
    ///   - step: The distance between detents. Leave `nil` for a continuous
    ///     value.
    ///   - onEditingChanged: Called with `true` when a finger comes down and
    ///     `false` when it lifts.
    public init<V: BinaryFloatingPoint>(
        _ style: ScrubberStyle = .ruler,
        value: Binding<V>,
        in range: ClosedRange<V> = 0...1,
        step: V.Stride? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) where V.Stride: BinaryFloatingPoint {
        self.style = style
        self.value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = V($0) }
        )
        self.scale = ScrubberScale(
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: step.map { Double($0) }
        )
        self.onEditingChanged = onEditingChanged
    }

    /// A scrubber over whole numbers. The value is always a whole step; the
    /// control still glides between them under your finger.
    public init<V: BinaryInteger>(
        _ style: ScrubberStyle = .ruler,
        value: Binding<V>,
        in range: ClosedRange<V>,
        step: V.Stride = 1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) where V.Stride: BinaryInteger {
        self.style = style
        self.value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = V(clamping: Int($0.rounded())) }
        )
        self.scale = ScrubberScale(
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(max(step, 1))
        )
        self.onEditingChanged = onEditingChanged
    }

    @Environment(\.scrubberLabeler) private var labeler
    @Environment(\.scrubberSnapping) private var snapping
    @Environment(\.scrubberHaptics) private var haptics
    @Environment(\.scrubberPuppet) private var puppet
    @Environment(\.scrubberIcons) private var icons
    @Environment(\.scrubberEmoji) private var emoji
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A finger's gesture in progress.
    private struct Session {
        var startFraction: Double
        var startLocation: CGPoint
        /// Angular mappings: the last angle seen and the unwrapped turn
        /// since the press, in radians.
        var lastAngle: Double = 0
        var turned: Double = 0
        /// Puppets: where the finger was pressed, in fractions.
        var pressFraction: Double = 0
        var lastRaw: Double
        var lastTime: TimeInterval
        var velocity: Double = 0
    }

    @State private var session: Session?
    /// The finger's position while one is down; `nil` at rest, when the
    /// control shows the bound value.
    @State private var live: Double?
    @State private var lift: Double = 0
    @State private var stretch: Double = 0
    @State private var velocity: Double = 0
    /// The control's size, for scripted fingers, which have no location.
    @State private var size: CGSize = .zero
    /// The last scripted-finger event played.
    @State private var playedSerial = 0

    private var restingFraction: Double { scale.fraction(of: value.wrappedValue) }
    private var shownFraction: Double { live ?? restingFraction }

    public var body: some View {
        let spec = style.spec(scale: scale, icons: icons != nil)
        GeometryReader { geo in
            let size = geo.size
            face(size: size)
                .contentShape(Rectangle())
                .gesture(drag(size: size, spec: spec), including: isEnabled ? .all : .subviews)
        }
        .frame(width: spec.width, height: spec.height)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onChange(of: puppet?.touch?.serial) { _, _ in
            guard let puppet else { return }
            for touch in puppet.events(after: playedSerial) {
                perform(touch, size: size, spec: spec)
                playedSerial = touch.serial
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        // To VoiceOver (and to UI tests) every style is a standard slider,
        // stepping by its detents, reading out the same text it shows.
        .accessibilityRepresentation {
            if let step = scale.step {
                Slider(value: value, in: scale.lower...scale.upper, step: step)
                    .accessibilityValue(accessibilityText)
            } else {
                Slider(value: value, in: scale.lower...scale.upper)
                    .accessibilityValue(accessibilityText)
            }
        }
    }

    /// What VoiceOver reads: the value as the control labels it, or for
    /// `.mood`, the word for the feeling.
    private var accessibilityText: Text {
        if style == .mood, labeler == nil {
            return Text(MoodFace.words[MoodFace.band(restingFraction)])
        }
        return ScrubberContext(scale: scale, labeler: labeler, haptics: false, size: .zero).label(value.wrappedValue)
    }

    // MARK: - Drawing

    @ViewBuilder
    private func face(size: CGSize) -> some View {
        let motion = ScrubberKinematics(fraction: shownFraction, lift: lift, stretch: stretch, velocity: velocity)
        let context = ScrubberContext(scale: scale, labeler: labeler, haptics: haptics, size: size)
        switch style {
        case .ruler: RulerFace(motion: motion, context: context)
        case .glass: GlassFace(motion: motion, context: context)
        case .jelly: JellyFace(motion: motion, context: context)
        case .elastic: ElasticFace(motion: motion, context: context, icons: icons)
        case .fluid: FluidFace(motion: motion, context: context)
        case .squiggle: SquiggleFace(motion: motion, context: context)
        case .thermostat: ThermostatFace(motion: motion, context: context)
        case .swing: SwingFace(motion: motion, context: context)
        case .mood: MoodFace(motion: motion, context: context)
        case .tape: TapeFace(motion: motion, context: context)
        case .effort: EffortFace(motion: motion, context: context)
        case .emoji: EmojiFace(motion: motion, context: context, emoji: emoji)
        }
    }

    // MARK: - Touch

    private func drag(size: CGSize, spec: ScrubberStyle.Spec) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { gesture in
                let time = gesture.time.timeIntervalSinceReferenceDate
                if session == nil {
                    begin(at: gesture.startLocation, pressFraction: nil, time: time, size: size, spec: spec)
                }
                move(to: raw(at: gesture.location, size: size, spec: spec), time: time, size: size, spec: spec)
            }
            .onEnded { gesture in
                end(at: gesture.time.timeIntervalSinceReferenceDate, flick: nil, size: size, spec: spec)
            }
    }

    /// Where a finger at `location` asks the control to be. Unclamped, so it
    /// can say how far past an end the finger has gone.
    private func raw(at location: CGPoint, size: CGSize, spec: ScrubberStyle.Spec) -> Double {
        guard let session else { return shownFraction }
        switch spec.mapping(size) {
        case .absolute(let leading, let trailing):
            return Double((location.x - leading) / max(size.width - leading - trailing, 1))
        case .relative(let points, let inverted):
            let travel = Double((location.x - session.startLocation.x) / max(points, 1))
            return session.startFraction + (inverted ? -travel : travel)
        case .angular(let center, let sweep):
            let angle = atan2(Double(location.y - center.y), Double(location.x - center.x))
            var delta = angle - session.lastAngle
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            let turned = session.turned + delta
            self.session?.lastAngle = angle
            self.session?.turned = turned
            return session.startFraction + turned / sweep
        }
    }

    private func begin(at location: CGPoint, pressFraction: Double?, time: TimeInterval, size: CGSize,
                       spec: ScrubberStyle.Spec) {
        var angle = 0.0
        if case .angular(let center, _) = spec.mapping(size) {
            angle = atan2(Double(location.y - center.y), Double(location.x - center.x))
        }
        session = Session(startFraction: shownFraction, startLocation: location, lastAngle: angle,
                          pressFraction: pressFraction ?? 0, lastRaw: shownFraction, lastTime: time)
        withAnimation(spec.liftIn.paced) { lift = 1 }
        onEditingChanged(true)
    }

    private func move(to raw: Double, time: TimeInterval, size: CGSize, spec: ScrubberStyle.Spec) {
        guard var session else { return }
        let clamped = min(max(raw, 0), 1)

        // Past an end, the finger's overshoot becomes a rubber-banded stretch.
        let past = (raw - clamped) * Double(spec.pointsPerRange(size))
        let banded = spec.stretches ? ScrubberMotion.rubberBand(past, dimension: Double(spec.bandDimension(size))) : 0

        let dt = max(time - session.lastTime, 1.0 / 240)
        if time > session.lastTime {
            // In scrubber time, so a slowed demo swings as a real one does.
            let instant = (clamped - session.lastRaw) / (dt * ScrubberTime.rate)
            session.velocity = session.velocity * 0.7 + instant * 0.3
            session.lastRaw = clamped
            session.lastTime = time
        }
        self.session = session

        live = clamped
        stretch = banded
        // Set straight, not animated: a spring retargeted on every event
        // stacks up rather than merging once it's slowed for a demo, and
        // the smoothing above is enough while the finger is down.
        velocity = session.velocity

        // A finger that stops sends no more events, so the speed would hang
        // at its last value: let it fall to zero once the finger has been
        // still for a moment.
        let stamp = session.lastTime
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(70 / ScrubberTime.rate))
            guard let current = self.session, current.lastTime == stamp, current.velocity != 0 else { return }
            self.session?.velocity = 0
            withAnimation((reduceMotion ? .easeOut(duration: 0.2) : spec.swingBack).paced) { velocity = 0 }
        }

        let next = snapping == .always ? scale.value(at: scale.snapped(clamped)) : scale.value(at: clamped)
        if next != value.wrappedValue { value.wrappedValue = next }
    }

    private func end(at time: TimeInterval, flick: Double?, size: CGSize, spec: ScrubberStyle.Spec) {
        guard let session else { return }
        self.session = nil
        let current = live ?? restingFraction

        // A finger that stopped before it lifted has no flick left in it.
        let still = time - session.lastTime > 0.06 / ScrubberTime.rate
        let speed = flick ?? (still ? 0 : session.velocity)

        var target = current
        if spec.release == .coast, !reduceMotion {
            target = min(max(current + speed * ScrubberMotion.coastProjection, 0), 1)
        }
        let mark = scale.mark(nearest: target)
        let landing = scale.isStepped ? scale.fraction(ofMark: mark) : target
        let settled = scale.isStepped ? scale.value(ofMark: mark) : scale.value(at: landing)

        var animation = spec.settle
        if spec.release == .coast, abs(landing - current) > 0.0005 {
            // Carry the finger's speed into the glide, as a share of the
            // distance left to travel, which is how SwiftUI measures it.
            let carried = min(max(speed / (landing - current), 0), 12)
            animation = .interpolatingSpring(Spring(duration: 0.62, bounce: 0.04), initialVelocity: carried)
        }
        if reduceMotion { animation = .easeOut(duration: 0.2) }

        withAnimation(animation.paced) {
            live = nil
            if settled != value.wrappedValue { value.wrappedValue = settled }
        }
        withAnimation(spec.liftOut.paced) { lift = 0 }
        withAnimation((reduceMotion ? .easeOut(duration: 0.2) : spec.recoil).paced) { stretch = 0 }
        withAnimation((reduceMotion ? .easeOut(duration: 0.2) : spec.swingBack).paced) { velocity = 0 }
        onEditingChanged(false)
    }

    /// Plays one event from a scripted finger through the same path a real
    /// finger takes.
    private func perform(_ touch: ScrubberPuppet.Touch, size: CGSize, spec: ScrubberStyle.Spec) {
        let now = Date.timeIntervalSinceReferenceDate
        switch touch.phase {
        case .down:
            if session != nil { end(at: now, flick: 0, size: size, spec: spec) }
            begin(at: .zero, pressFraction: touch.fraction, time: now, size: size, spec: spec)
            move(to: puppetRaw(touch.fraction, spec: spec), time: now, size: size, spec: spec)
        case .moved:
            if session == nil {
                begin(at: .zero, pressFraction: touch.fraction, time: now, size: size, spec: spec)
            }
            move(to: puppetRaw(touch.fraction, spec: spec), time: now, size: size, spec: spec)
        case .up:
            end(at: now, flick: touch.flick, size: size, spec: spec)
        }
    }

    /// A puppet finger's position is already in fractions: where it is for
    /// a control that follows the finger, how far it has travelled for one
    /// that follows its travel.
    private func puppetRaw(_ fraction: Double, spec: ScrubberStyle.Spec) -> Double {
        guard let session else { return fraction }
        if case .absolute = spec.mapping(.zero) { return fraction }
        return session.startFraction + (fraction - session.pressFraction)
    }
}
