//
//  DemoStage.swift
//  ScrubbersDemo
//
//  The hero video's stage (SCRUBBERS_DEMO=1). Every example stands in one
//  column; the active one sits in the middle at full strength while the
//  others wait, dimmed, above and below, and a scripted finger works each
//  control through its best moment before the column rolls on to the next.
//  The page confines itself to a 9:16 band of the screen, so a frameless
//  video can be cut straight from a simulator recording. SCRUBBERS_PACE=3
//  plays it all three times slower, to speed back up in post.
//
//  Simulator recordings are silent, so every haptic tick is also written
//  into a small barcode below the band (outside the video): a counter, the
//  kind of tick and the mark it landed on. Scripts/ticks.py reads it
//  back out of the recording and lays a click on the frame each tick
//  happened.
//

import SwiftUI
@_spi(Demo) import Scrubbers

struct DemoStage: View {
    private let examples = ScrubberExample.all

    @State private var values: [ScrubberStyle: Double] =
        Dictionary(uniqueKeysWithValues: ScrubberExample.all.map { ($0.style, $0.initial) })
    @State private var puppets: [ScrubberStyle: ScrubberPuppet] =
        Dictionary(uniqueKeysWithValues: ScrubberStyle.allCases.map { ($0, ScrubberPuppet()) })
    @State private var active = 0
    @State private var ticks = TickCode()

    /// 9:16 of the screen's width: what a frameless portrait video keeps.
    static var bandHeight: CGFloat { UIScreen.main.bounds.width * 16 / 9 }
    private static let gap: CGFloat = 54
    private static let caption: CGFloat = 30
    private static let code: CGFloat = 34

    private func rowHeight(_ style: ScrubberStyle) -> CGFloat {
        Self.caption + DemoMetrics.controlHeight(style) + Self.code
    }

    /// Where each row's top sits in the column.
    private var rowTops: [CGFloat] {
        var top: CGFloat = 0
        return examples.map { example in
            defer { top += rowHeight(example.style) + Self.gap }
            return top
        }
    }

    var body: some View {
        let band = Self.bandHeight
        let tops = rowTops
        // The column rises so the active row's middle is the band's.
        let rise = tops[active] + rowHeight(examples[active].style) / 2 - band / 2
        ZStack(alignment: .top) {
            // Every row is built once, at launch, so nothing is created mid
            // roll; the ones far from the active row are hidden.
            ForEach(Array(examples.enumerated()), id: \.element.id) { index, example in
                row(example, isActive: index == active)
                    .frame(height: rowHeight(example.style))
                    .offset(y: tops[index] - rise)
                    .opacity(abs(index - active) <= 2 ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.62, dampingFraction: 0.88).speed(ScrubberTime.rate), value: active)
        .frame(maxWidth: .infinity)
        .frame(height: band, alignment: .top)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            ticks.barcode
                .padding(.bottom, (UIScreen.main.bounds.height - band) / 4)
        }
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .toolbar(.hidden, for: .navigationBar)
        .task { await run() }
    }

    private func row(_ example: ScrubberExample, isActive: Bool) -> some View {
        let binding = Binding(
            get: { values[example.style] ?? example.initial },
            set: { values[example.style] = $0 }
        )
        return VStack(spacing: 0) {
            Text(example.style.title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.black)
                .frame(height: Self.caption, alignment: .top)
            ScrubberExampleControl(example: example, puppet: puppets[example.style], value: binding)
                .frame(height: DemoMetrics.controlHeight(example.style))
            Text("Scrubber(\(example.code), value: $value)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.black.opacity(0.45))
                .frame(height: Self.code, alignment: .bottom)
        }
        .padding(.horizontal, 36)
        .scrubberAnimating(isActive)
        .opacity(isActive ? 1 : 0.14)
        .scaleEffect(isActive ? 1.12 : 0.92)
        .animation(.easeInOut(duration: 0.45).speed(ScrubberTime.rate), value: isActive)
        .allowsHitTesting(isActive)
    }

    // MARK: - The walk

    /// SCRUBBERS_PACE=3 runs everything three times slower (springs, glides,
    /// clocks, physics), for a smooth recording on a busy machine; speed the
    /// video up by the same factor afterwards.
    static let pace = ProcessInfo.processInfo.environment["SCRUBBERS_PACE"].flatMap(Double.init) ?? 1

    private func run() async {
        ScrubberTime.rate = 1 / Self.pace
        ScrubberTelemetry.shared.isRecording = true
        ScrubberTelemetry.shared.onTick = { tick in ticks.record(tick) }
        guard await pause(0.8) else { return }
        for (index, example) in examples.enumerated() {
            if index > 0 {
                active = index
                // The next walk starts while the column is still settling.
                guard await pause(0.4) else { return }
            }
            guard let finger = puppets[example.style] else { continue }
            let at = fraction(of: example)
            guard await DemoWalk.play(example.style, finger, from: at, current: { fraction(of: example) }) else { return }
        }
        _ = await pause(2.2)
        ScrubberTelemetry.shared.isRecording = false
    }

    private func fraction(of example: ScrubberExample) -> Double {
        let value = values[example.style] ?? example.initial
        let span = example.range.upperBound - example.range.lowerBound
        return span > 0 ? (value - example.range.lowerBound) / span : 0
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds / ScrubberTime.rate))
        return !Task.isCancelled
    }
}

/// The controls' own heights, so the column can place its rows before it
/// lays them out.
enum DemoMetrics {
    static func controlHeight(_ style: ScrubberStyle) -> CGFloat {
        switch style {
        case .ruler: return 78
        case .glass: return 52
        case .jelly: return 106
        case .elastic: return 52
        case .fluid: return 92
        case .squiggle: return 44
        case .thermostat: return 250
        case .swing: return 92
        case .mood: return 250
        case .tape: return 122
        case .effort: return 150
        case .emoji: return 100
        }
    }
}

/// What the scripted finger does to each style: its best moment, in about
/// two seconds.
enum DemoWalk {
    /// Plays one style's walk. `from` is where the control starts, as a
    /// fraction; `current` reads where it is now (after a coast). Returns
    /// false if cancelled.
    @MainActor
    static func play(_ style: ScrubberStyle, _ p: ScrubberPuppet, from start: Double,
                     current: @MainActor () -> Double) async -> Bool {
        func go(_ to: Double, _ seconds: Double, _ curve: ScrubberPuppet.Curve = .easeInOut) async -> Bool {
            await p.glide(to: to, over: seconds, curve: curve)
        }
        func wait(_ seconds: Double) async -> Bool { await p.hold(seconds) }

        switch style {
        case .ruler:
            p.press(at: start)
            guard await go(0.08, 0.6), await go(0.95, 0.8), await go(0.63, 0.4) else { return false }
            p.release()
            return await wait(0.35)

        case .glass:
            p.press(at: start)
            guard await wait(0.3), await go(0.9, 0.5), await go(0.25, 0.55), await go(0.55, 0.35) else { return false }
            p.release()
            return await wait(0.45)

        case .jelly:
            p.press(at: start)
            guard await go(0.97, 0.35), await wait(0.1), await go(0.3, 0.24, .easeOut), await wait(0.85),
                  await go(0.78, 0.45) else { return false }
            p.release()
            return await wait(0.3)

        case .elastic:
            p.press(at: start)
            guard await go(-0.4, 0.6), await wait(0.1), await go(1.45, 0.85), await wait(0.1) else { return false }
            p.release()
            return await wait(0.55)

        case .fluid:
            p.press(at: start)
            guard await wait(0.3), await go(0.85, 0.55), await go(0.25, 0.6), await go(0.6, 0.35) else { return false }
            p.release()
            return await wait(0.45)

        case .squiggle:
            guard await wait(0.45) else { return false }
            p.press(at: start)
            guard await wait(0.2), await go(0.82, 0.6) else { return false }
            p.release()
            return await wait(0.85)

        case .thermostat:
            p.press(at: start)
            guard await go(0.9, 0.7), await wait(0.2), await go(0.1, 0.85), await wait(0.2),
                  await go(0.48, 0.45) else { return false }
            p.release()
            return await wait(0.25)

        case .swing:
            p.press(at: start)
            guard await wait(0.15), await go(0.86, 0.45, .easeIn), await wait(0.7),
                  await go(0.3, 0.4, .easeIn) else { return false }
            p.release()
            return await wait(0.6)

        case .mood:
            p.press(at: start)
            guard await go(0.02, 0.7), await wait(0.25), await go(0.98, 1.0), await wait(0.25),
                  await go(0.7, 0.35) else { return false }
            p.release()
            return await wait(0.2)

        case .tape:
            p.press(at: start)
            guard await go(start - 0.1, 0.28, .easeIn) else { return false }
            p.release(flick: -0.55)
            guard await wait(0.9) else { return false }
            let here = current()
            p.press(at: here)
            guard await go(here + 0.12, 0.28, .easeIn) else { return false }
            p.release(flick: 0.5)
            return await wait(0.9)

        case .effort:
            p.press(at: start)
            guard await go(0.02, 0.5), await wait(0.1), await go(1.0, 1.0), await wait(0.15),
                  await go(0.62, 0.35) else { return false }
            p.release()
            return await wait(0.3)

        case .emoji:
            p.press(at: start)
            guard await go(0.04, 0.5), await go(0.96, 0.8), await wait(0.15) else { return false }
            p.release()
            return await wait(1.1)
        }
    }
}

/// Every tick, written as a barcode a script can read back out of the
/// recording: ten bits of running count, two of kind (tick, knock or burst),
/// four of the mark it landed on.
struct TickCode {
    private(set) var count = 0
    private(set) var kind = 0
    private(set) var mark = 0

    mutating func record(_ tick: ScrubberTelemetry.Tick) {
        count = (count + 1) % 1024
        kind = tick.kind.rawValue
        mark = tick.mark & 15
    }

    var bits: [Bool] {
        (0..<10).map { count >> (9 - $0) & 1 == 1 }
            + (0..<2).map { kind >> (1 - $0) & 1 == 1 }
            + (0..<4).map { mark >> (3 - $0) & 1 == 1 }
    }

    /// Sixteen squares, black for one, white for zero, on a black frame so
    /// the reader can find them.
    var barcode: some View {
        HStack(spacing: 0) {
            ForEach(Array(bits.enumerated()), id: \.offset) { _, bit in
                Rectangle()
                    .fill(bit ? Color.black : Color.white)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(4)
        .background(Color.black)
    }
}
