//
//  JellyFace.swift
//  Scrubbers
//
//  A strip of jelly in a slot. Its left end is pinned; its right end is
//  the handle. Push the handle back faster than the jelly can shorten and it
//  can't fit, so it buckles up into a hump that wobbles and settles; pull it
//  out and it stretches thin before it catches up. After Voicu Apostol's
//  Jelly Slider and Software Mansion's real-time port, whose Verlet chain
//  (17 points, 6 substeps, 16 constraint passes, an arch force that grows
//  with compression) this follows. Here the jelly's length relaxes toward
//  the handle, so at rest it lies flat and its length is the value.
//

import SwiftUI

struct JellyFace: View, Animatable {
    var motion: ScrubberKinematics
    let context: ScrubberContext

    @State private var sim = JellySim()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated static let slotHeight: CGFloat = 36
    /// Room above the slot for the jelly to hump into.
    nonisolated static let headroom: CGFloat = 70
    nonisolated static var height: CGFloat { slotHeight + headroom }
    /// From the slot's ends to the jelly's pinned end and furthest reach.
    nonisolated static let inset: CGFloat = 22
    /// The jelly never gets shorter than this, so there's always some to see.
    nonisolated static let minimumLength: CGFloat = 34
    nonisolated static let thickness: CGFloat = 24

    nonisolated var animatableData: ScrubberKinematics {
        get { motion }
        set { motion = newValue }
    }

    var body: some View {
        let size = context.size
        let track = max(size.width - Self.inset * 2 - Self.minimumLength, 1)
        let reach = Self.minimumLength + track * CGFloat(motion.fraction)
        let settled = sim.settledReach.map { abs($0 - reach) < 0.25 } ?? false

        LiveTime(running: motion.lift > 0 || !settled) { seconds in
            Canvas { context, size in
                if reduceMotion { sim.snap(to: reach) } else { sim.step(to: reach, at: seconds) }
                let baseY = size.height - Self.slotHeight / 2
                drawSlot(in: &context, size: size)
                drawJelly(in: &context, baseY: baseY)
            }
        }
        .overlay(alignment: .topLeading) { readout.padding(.leading, 4) }
        .scrubberFeedback(motion, context, ticksWhenContinuous: false)
    }

    private func drawSlot(in context: inout GraphicsContext, size: CGSize) {
        let slot = CGRect(x: 0, y: size.height - Self.slotHeight, width: size.width, height: Self.slotHeight)
        let shape = Path(roundedRect: slot, cornerRadius: Self.slotHeight / 2, style: .continuous)
        context.opacity = 1
        context.fill(shape, with: .style(.foreground.opacity(0.06)))
        // A recess: shadow along the inside of the top edge.
        context.drawLayer { layer in
            layer.clip(to: shape)
            layer.addFilter(.blur(radius: 3))
            var lip = Path()
            lip.addRoundedRect(in: slot.insetBy(dx: -4, dy: -4).offsetBy(dx: 0, dy: -3),
                               cornerSize: CGSize(width: Self.slotHeight / 2 + 4, height: Self.slotHeight / 2 + 4))
            layer.stroke(lip, with: .color(.black.opacity(0.16)), lineWidth: 6)
        }
    }

    private func drawJelly(in context: inout GraphicsContext, baseY: CGFloat) {
        let points = sim.points.map { CGPoint(x: Self.inset + $0.x, y: baseY - $0.y) }
        guard points.count > 1 else { return }
        let path = Self.smooth(points)
        // Stretched, the jelly thins; squashed, it fattens, as if it kept its
        // volume.
        let width = Self.thickness * CGFloat(min(max(sqrt(sim.restLength / max(sim.reach, 1)), 0.72), 1.3))
        let round = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)

        // Shadow on the slot floor.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.translateBy(x: 0, y: 4)
            layer.stroke(path, with: .color(.black.opacity(0.22)), style: round)
        }
        // The body: the tint, a little see-through.
        context.opacity = 0.95
        context.stroke(path, with: .style(.tint), style: round)
        // A darker underside where the light passes through less jelly.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 2))
            layer.translateBy(x: 0, y: width * 0.28)
            layer.stroke(path, with: .color(.black.opacity(0.14)),
                         style: StrokeStyle(lineWidth: width * 0.34, lineCap: .round, lineJoin: .round))
        }
        // Light scattered inside it: a soft lighter core, high in the body.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            layer.translateBy(x: 0, y: -width * 0.1)
            layer.stroke(path, with: .color(.white.opacity(0.3)),
                         style: StrokeStyle(lineWidth: width * 0.5, lineCap: .round, lineJoin: .round))
        }
        // And a crisp specular streak along the top.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.8))
            layer.translateBy(x: 0, y: -width * 0.27)
            layer.stroke(path.trimmedPath(from: 0.04, to: 0.96), with: .color(.white.opacity(0.8)),
                         style: StrokeStyle(lineWidth: width * 0.13, lineCap: .round, lineJoin: .round))
        }
        context.opacity = 1
    }

    /// A smooth curve through the chain: quadratic segments between the
    /// midpoints, with the chain's points as their control points.
    static func smooth(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        if points.count == 2 { path.addLine(to: points[1]); return path }
        for i in 1..<(points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            path.addQuadCurve(to: i == points.count - 2 ? points[i + 1] : mid, control: points[i])
        }
        return path
    }

    private var readout: some View {
        let scale = context.scale
        let mark = scale.isStepped ? scale.mark(nearest: motion.fraction) : Int((motion.fraction * 100).rounded())
        let shown = scale.isStepped ? scale.value(ofMark: mark) : scale.value(at: Double(mark) / 100)
        return context.label(shown)
            .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.foreground.opacity(0.85))
            .contentTransition(.numericText(value: shown))
            .animation(.snappy(duration: 0.2).paced, value: mark)
    }
}

/// The jelly's physics, stepped once per frame from the canvas that draws
/// it. A chain of points with fixed spacing: the first pinned, the last held
/// by the handle, the rest free under Verlet integration.
@MainActor
@Observable
final class JellySim {
    private static let count = 17
    private static let substeps = 6
    private static let iterations = 16
    /// How long the jelly's wobble takes to die away by a factor of e: the
    /// original's 1% per substep at 60 fps, made independent of frame rate.
    private static let damping = 0.276
    private static let bending = 0.1
    private static let bendingExponent = 1.2
    private static let endFlatten = 0.05
    /// Upward push at full compression, as a share of the jelly's length per
    /// second squared.
    private static let arch = 1.05
    /// How quickly the jelly's own length catches up with the handle.
    private static let relax = 0.3
    /// The tallest the hump may rise, in points.
    private static let maxHump: CGFloat = 54
    /// How closely the jelly's end follows the handle: a little drag.
    private static let follow = 0.11

    /// Where the chain's points are, with x along the slot from the pinned
    /// end and y up from the slot's centre line. Not observed: it changes
    /// every frame and is only read by the canvas that steps it.
    @ObservationIgnored private(set) var points: [CGPoint] = []
    @ObservationIgnored private var previous: [CGPoint] = []
    /// The jelly's natural length, which relaxes toward the handle's reach.
    @ObservationIgnored private(set) var restLength: CGFloat = 0
    /// Where the jelly's free end is.
    @ObservationIgnored private(set) var reach: CGFloat = 0
    @ObservationIgnored private var lastTime: Double?

    /// The reach the jelly last came to rest at, so the view can stop the
    /// clock until the handle moves again.
    var settledReach: CGFloat?

    func step(to target: CGFloat, at time: Double) {
        if points.isEmpty { reset(to: target) }
        let dt = min(max(time - (lastTime ?? time), 0), 1.0 / 30)
        lastTime = time
        guard dt > 0 else { return }

        reach += (target - reach) * CGFloat(1 - exp(-dt / Self.follow))
        restLength += (reach - restLength) * CGFloat(1 - exp(-dt / Self.relax))
        // However hard it's pushed, the jelly gives way rather than loop over
        // itself: a chain `excess` longer than the gap it spans humps about
        // (2/π)·√(gap·excess) high, so cap the excess to keep the hump
        // under `maxHump`.
        let excess = pow(Self.maxHump / (2 / .pi), 2) / max(reach, 1)
        restLength = min(restLength, reach + excess)

        let h = dt / Double(Self.substeps)
        let compression = max(0, 1 - Double(reach / max(restLength, 1)))
        for _ in 0..<Self.substeps {
            integrate(h: h, compression: compression)
            project()
        }

        let moving = zip(points, previous).contains { abs($0.x - $1.x) + abs($0.y - $1.y) > 0.02 }
        if !moving, abs(target - reach) < 0.25, abs(restLength - reach) < 0.25 {
            let rest = target
            if settledReach != rest {
                Task { @MainActor in self.settledReach = rest }
            }
        } else if settledReach != nil {
            Task { @MainActor in self.settledReach = nil }
        }
    }

    private func reset(to target: CGFloat) {
        reach = target
        restLength = target
        points = (0..<Self.count).map { CGPoint(x: target * CGFloat($0) / CGFloat(Self.count - 1), y: 0) }
        previous = points
    }

    /// Lays the jelly flat at `target` at once, for Reduce Motion.
    func snap(to target: CGFloat) {
        reset(to: target)
        lastTime = nil
    }

    private func integrate(h: Double, compression: Double) {
        let last = Self.count - 1
        let lift = Self.arch * Double(restLength) * compression
        let keep = CGFloat(exp(-h / Self.damping))
        for i in 1..<last {
            let p = points[i]
            let v = CGPoint(x: (p.x - previous[i].x) * keep, y: (p.y - previous[i].y) * keep)
            // The arch: an upward push, strongest mid-chain, when the ends are
            // closer together than the jelly is long.
            let t = Double(i) / Double(last)
            let window = smoothstep(0.01, 0.99, t) * smoothstep(0.01, 0.99, 1 - t)
            let ay = lift * sin(.pi * t) * window
            previous[i] = p
            points[i] = CGPoint(x: p.x + v.x, y: max(p.y + v.y + CGFloat(ay * h * h), 0))
        }
        pinEnds()
    }

    private func project() {
        let last = Self.count - 1
        let segment = restLength / CGFloat(last)
        for _ in 0..<Self.iterations {
            for i in 0..<last { constrain(i, i + 1, segment, 0.1) }
            // Stiffer toward the ends, so the hump rises from the middle.
            for i in 1..<last {
                let t = Double(i) / Double(last)
                let strength = pow(abs(t - 0.5) * 2, Self.bendingExponent)
                constrain(i - 1, i + 1, segment * 2, CGFloat(Self.bending * (0.05 + 0.95 * strength)))
            }
            for i in [1, last - 1] { points[i].y += (0 - points[i].y) * CGFloat(Self.endFlatten) }
            pinEnds()
        }
    }

    private func pinEnds() {
        let last = Self.count - 1
        points[0] = .zero
        previous[0] = .zero
        points[last] = CGPoint(x: reach, y: 0)
        previous[last] = points[last]
    }

    private func constrain(_ i: Int, _ j: Int, _ rest: CGFloat, _ k: CGFloat) {
        let dx = points[j].x - points[i].x
        let dy = points[j].y - points[i].y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 1e-6 else { return }
        let last = Self.count - 1
        let wi: CGFloat = i == 0 || i == last ? 0 : 1
        let wj: CGFloat = j == 0 || j == last ? 0 : 1
        guard wi + wj > 0 else { return }
        let diff = (length - rest) / length
        let ci = wi / (wi + wj) * k
        let cj = wj / (wi + wj) * k
        points[i].x += dx * diff * ci
        points[i].y += dy * diff * ci
        points[j].x -= dx * diff * cj
        points[j].y -= dy * diff * cj
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
