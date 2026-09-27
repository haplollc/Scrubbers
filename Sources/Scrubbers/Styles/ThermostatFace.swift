//
//  ThermostatFace.swift
//  Scrubbers
//
//  A round face ringed by fine ticks, with the value large in the middle.
//  Turn it by dragging round the ring: the ticks light up to the value, a
//  long bright tick marks it, and the face floods cool blue below the middle
//  of the range and warm orange above it, dark in between. After the Nest
//  Learning Thermostat.
//

import SwiftUI

struct ThermostatFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let height: CGFloat = 250
    /// The ring's opening sits at the bottom; the ticks sweep 300° from
    /// lower left, clockwise, to lower right.
    nonisolated static let sweep: Double = 300 * .pi / 180
    nonisolated static let startAngle: Double = 120 * .pi / 180

    private static let tickCount = 90
    nonisolated static let cool = (0.09, 0.47, 1.0)
    nonisolated static let warm = (1.0, 0.42, 0.05)

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let size = context.size
        let diameter = min(size.width, size.height) - 8
        let fraction = motion.fraction
        let lift = motion.lift

        ZStack {
            face(diameter: diameter, fraction: fraction)
            Canvas { context, canvas in
                let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let outer = diameter / 2 - 10
                let valueAngle = Self.startAngle + Self.sweep * fraction
                for tick in 0...Self.tickCount {
                    let t = Double(tick) / Double(Self.tickCount)
                    let angle = Self.startAngle + Self.sweep * t
                    let lit = t <= fraction + 0.0001
                    let length: CGFloat = lit ? 13 : 10
                    let direction = CGPoint(x: cos(angle), y: sin(angle))
                    var line = Path()
                    line.move(to: CGPoint(x: center.x + direction.x * outer, y: center.y + direction.y * outer))
                    line.addLine(to: CGPoint(x: center.x + direction.x * (outer - length),
                                             y: center.y + direction.y * (outer - length)))
                    context.opacity = lit ? 0.9 : 0.28
                    context.stroke(line, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                // The value's own tick: long and bright, reaching in.
                let direction = CGPoint(x: cos(valueAngle), y: sin(valueAngle))
                var marker = Path()
                marker.move(to: CGPoint(x: center.x + direction.x * (outer + 2), y: center.y + direction.y * (outer + 2)))
                marker.addLine(to: CGPoint(x: center.x + direction.x * (outer - 26 - 4 * lift),
                                           y: center.y + direction.y * (outer - 26 - 4 * lift)))
                context.opacity = 1
                context.stroke(marker, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            readout(diameter: diameter)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(1 - 0.02 * lift)
        .frame(width: size.width, height: size.height)
        .scrubberFeedback(motion, context)
    }

    /// Dark through the middle of the range. Past a third of the way from
    /// either end the face floods: cool blue toward the bottom, warm orange
    /// toward the top, washing out from the centre as it changes over, as
    /// Nest's does when it starts cooling or heating.
    private func face(diameter: CGFloat, fraction: Double) -> some View {
        let mode = fraction > 0.64 ? 1 : (fraction < 0.36 ? -1 : 0)
        func tone(_ c: (Double, Double, Double)) -> Color { Color(.sRGB, red: c.0, green: c.1, blue: c.2) }
        return ZStack {
            Circle().fill(Color(.sRGB, red: 0.07, green: 0.07, blue: 0.08).gradient)
            // Solid colour spreading from the middle: fading it in over the
            // dark face instead would pass through a muddy brown.
            Circle()
                .fill(tone(Self.warm).gradient)
                .scaleEffect(mode == 1 ? 1 : 0.001)
            Circle()
                .fill(tone(Self.cool).gradient)
                .scaleEffect(mode == -1 ? 1 : 0.001)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86).paced, value: mode)
        .clipShape(Circle())
        .overlay {
            // A soft sheen from above, and a dark rim, so it reads as a
            // curved glass face rather than a flat disc.
            Circle().fill(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center))
        }
        .overlay { Circle().strokeBorder(.black.opacity(0.35), lineWidth: 3) }
        .frame(width: diameter, height: diameter)
        .background {
            // A soft shadow on the wall behind it, drawn rather than cast,
            // so it costs nothing while the face animates.
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(0.28), .black.opacity(0)],
                                     center: .center, startRadius: diameter * 0.3, endRadius: diameter * 0.56))
                .frame(width: diameter * 1.08, height: diameter * 1.08)
                .offset(y: 9)
        }
    }

    private func readout(diameter: CGFloat) -> some View {
        let scale = context.scale
        let mark = scale.isStepped ? scale.mark(nearest: motion.fraction) : Int((motion.fraction * 100).rounded())
        let shown = scale.isStepped ? scale.value(ofMark: mark) : scale.value(at: Double(mark) / 100)
        return context.label(shown)
            .font(.system(size: diameter * 0.3, weight: .ultraLight).monospacedDigit())
            .foregroundStyle(.white)
            .contentTransition(.numericText(value: shown))
            .animation(.snappy(duration: 0.24).paced, value: mark)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: diameter * 0.62)
    }
}
