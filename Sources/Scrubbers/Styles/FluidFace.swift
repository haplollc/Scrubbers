//
//  FluidFace.swift
//  Scrubbers
//
//  A fat bar with the value in a white bead. Touch it and the bead rises out
//  of the bar in a drop of the bar's own colour, pulling a gooey neck that
//  stretches and snaps; let go and it drips back in. After Virgil Pana's
//  Fluid Slider, open-sourced by Ramotion.
//

import SwiftUI

struct FluidFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    nonisolated static let barHeight: CGFloat = 38
    /// Room above the bar for the drop to rise into.
    nonisolated static let headroom: CGFloat = 54
    nonisolated static var height: CGFloat { barHeight + headroom }
    /// The drop's radius, and the white bead's inside it.
    nonisolated static let drop: CGFloat = 20
    nonisolated static let bead: CGFloat = 15
    /// The bead's centre can reach the bar's ends, less a margin.
    nonisolated static let inset: CGFloat = 26

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let size = context.size
        let lift = CGFloat(motion.lift)
        let track = size.width - Self.inset * 2
        let x = Self.inset + track * CGFloat(motion.fraction)
        let barTop = size.height - Self.barHeight
        let barMid = barTop + Self.barHeight / 2
        // Risen, the drop's centre sits a little clear of the bar's top edge,
        // leaning back a touch against the way it's moving.
        let risenY = barTop - Self.drop - 10
        let dropY = barMid + (risenY - barMid) * lift
        let lean = CGFloat(min(max(motion.velocity * 10, -9), 9)) * lift
        let dropX = x - lean

        ZStack(alignment: .topLeading) {
            // The goo: the bar and the drop, blurred together and cut at half
            // opacity, so where they are close they join in a neck. It's
            // drawn as a mask over the tint so it takes the app's colour.
            Rectangle()
                .fill(.tint)
                .mask {
                    Canvas { context, _ in
                        context.addFilter(.alphaThreshold(min: 0.5, color: .white))
                        context.addFilter(.blur(radius: 9))
                        context.drawLayer { layer in
                            let bar = CGRect(x: 0, y: barTop, width: size.width, height: Self.barHeight)
                            layer.fill(Path(roundedRect: bar, cornerRadius: 12, style: .continuous), with: .color(.white))
                            let drop = CGRect(x: dropX - Self.drop, y: dropY - Self.drop,
                                              width: Self.drop * 2, height: Self.drop * 2)
                            layer.fill(Path(ellipseIn: drop), with: .color(.white))
                        }
                    }
                    .blur(radius: 0.6)
                }

            ends(barMid: barMid, beadX: dropX, width: size.width)

            // The bead with the value, riding in the drop.
            Circle()
                .fill(.white)
                .frame(width: Self.bead * 2, height: Self.bead * 2)
                .overlay { readout }
                .scaleEffect(1 + 0.08 * lift)
                .position(x: dropX, y: dropY)
        }
        .frame(width: size.width, height: size.height)
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }

    /// The range's ends, in white inside the bar, stepping aside when the
    /// bead comes near.
    private func ends(barMid: CGFloat, beadX: CGFloat, width: CGFloat) -> some View {
        let font = Font.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit()
        let near: CGFloat = 46
        return ZStack {
            context.label(context.scale.lower)
                .font(font)
                .fixedSize()
                .position(x: 18, y: barMid)
                .opacity(beadX < 18 + near ? 0 : 1)
            context.label(context.scale.upper)
                .font(font)
                .fixedSize()
                .position(x: width - 18, y: barMid)
                .opacity(beadX > width - 18 - near ? 0 : 1)
        }
        .foregroundStyle(.background.opacity(0.9))
        .animation(.easeOut(duration: 0.15).paced, value: beadX < 18 + near)
        .animation(.easeOut(duration: 0.15).paced, value: beadX > width - 18 - near)
    }

    private var readout: some View {
        let scale = context.scale
        let mark = scale.isStepped ? scale.mark(nearest: motion.fraction) : Int((motion.fraction * 100).rounded())
        let shown = scale.isStepped ? scale.value(ofMark: mark) : scale.value(at: Double(mark) / 100)
        return context.label(shown)
            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.tint)
            .contentTransition(.numericText(value: shown))
            .animation(.snappy(duration: 0.2).paced, value: mark)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(3)
    }
}
