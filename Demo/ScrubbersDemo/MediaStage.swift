//
//  MediaStage.swift
//  ScrubbersDemo
//
//  One control alone on GitHub's page colour, looping its scripted walk, for
//  the README's GIFs (SCRUBBERS_MEDIA=<style>, SCRUBBERS_SCHEME=light|dark).
//  Each loop ends by gliding back to where it started, so the GIF loops
//  without a jump, and a square above the crop flips at the start of every
//  loop so a script can cut exactly one.
//

import SwiftUI
@_spi(Demo) import Scrubbers

struct MediaStage: View {
    let example: ScrubberExample
    let dark: Bool

    @State private var value: Double
    @State private var finger = ScrubberPuppet()
    @State private var loops = 0

    /// Where the control's box starts, from the top of the screen, and the
    /// margin kept round it: Scripts/readme_media.sh crops to this.
    static let boxTop: CGFloat = 220
    static let margin: CGFloat = 28

    init(example: ScrubberExample, dark: Bool) {
        self.example = example
        self.dark = dark
        _value = State(initialValue: example.initial)
    }

    /// GitHub's page colours, so each GIF sits seamlessly on its theme.
    private var page: Color {
        dark ? Color(red: 13 / 255, green: 17 / 255, blue: 23 / 255) : .white
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            page.ignoresSafeArea()
            ScrubberExampleControl(example: example, puppet: finger, value: $value)
                .frame(height: DemoMetrics.controlHeight(example.style))
                .padding(.horizontal, Self.margin)
                .offset(y: Self.boxTop)
            Rectangle()
                .fill(loops.isMultiple(of: 2) ? Color.black : Color.white)
                .frame(width: 40, height: 40)
                .offset(x: 0, y: 30)
        }
        .ignoresSafeArea()
        .preferredColorScheme(dark ? .dark : .light)
        .toolbar(.hidden, for: .navigationBar)
        .task { await run() }
    }

    private var fraction: Double {
        let span = example.range.upperBound - example.range.lowerBound
        return span > 0 ? (value - example.range.lowerBound) / span : 0
    }

    private func run() async {
        // SCRUBBERS_PACE=3 runs it all three times slower, as on the demo stage.
        ScrubberTime.rate = 1 / DemoStage.pace
        let home = fraction
        try? await Task.sleep(for: .seconds(0.8 / ScrubberTime.rate))
        while !Task.isCancelled {
            loops += 1
            guard await DemoWalk.play(example.style, finger, from: fraction, current: { fraction }) else { return }
            // Back to the start, so the last frame meets the first.
            finger.press(at: fraction)
            guard await finger.glide(to: home, over: 0.7) else { return }
            finger.release()
            guard await finger.hold(0.9) else { return }
        }
    }
}
