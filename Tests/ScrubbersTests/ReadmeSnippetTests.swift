//
//  ReadmeSnippetTests.swift
//  ScrubbersTests
//
//  Every code snippet in README.md, compiled against the PUBLIC API only (a
//  plain import, not @testable) and rendered once. If the README and the
//  package ever disagree, this file stops compiling.
//

import SwiftUI
import Testing
import Scrubbers

// MARK: - Snippets

private struct OneLine: View {
    @State private var value = 0.5
    var body: some View {
        Scrubber(.jelly, value: $value)
    }
}

private struct QuickStart: View {
    @State private var volume = 0.6

    var body: some View {
        Scrubber(.elastic, value: $volume)
            .scrubberIcons(low: "speaker.fill", high: "speaker.wave.3.fill")
    }
}

private struct EveryStyle: View {
    @State private var value = 0.5
    var body: some View {
        List(ScrubberStyle.allCases) { style in
            VStack(alignment: .leading) {
                Text(style.title)
                Scrubber(style, value: $value)
            }
        }
    }
}

private struct Values: View {
    @State private var brightness = 0.5
    @State private var weight = 72.5
    @State private var temperature = 68.0
    @State private var effort = 6
    var body: some View {
        VStack {
            Scrubber(.glass, value: $brightness)                                  // 0...1, continuous
            Scrubber(.tape, value: $weight, in: 40...120, step: 0.5)              // a detent every half kilo
            Scrubber(.thermostat, value: $temperature, in: 50...90, step: 1)      // a click a degree
            Scrubber(.effort, value: $effort, in: 1...10)                         // Int: whole steps
        }
    }
}

private struct Morphing: View {
    let years = Array(2007...2026)
    @State private var position = 9.0

    var body: some View {
        Scrubber(.ruler, value: $position, in: 0...Double(years.count - 1), step: 1)
            .scrubberSnapping(.onRelease)   // fractions while dragging, a whole year on release
            .scrubberLabels { Text(String(years[Int($0.rounded())])) }
    }
}

private struct Labels: View {
    @State private var year = 2016.0
    @State private var temperature = 68.0
    @State private var tip = 0.18
    var body: some View {
        VStack {
            Scrubber(.ruler, value: $year, in: 2007...2026, step: 1)
                .scrubberLabels { Text(String(Int($0))) }

            Scrubber(.thermostat, value: $temperature, in: 50...90, step: 1)
                .scrubberLabels { Text("\(Int($0))°") }

            Scrubber(.fluid, value: $tip, in: 0...0.3, step: 0.01)
                .scrubberLabels(format: .percent.precision(.fractionLength(0)))
        }
    }
}

private struct Styling: View {
    @State private var value = 0.5
    @State private var level = 0.7
    var body: some View {
        VStack {
            Scrubber(.jelly, value: $value)
                .tint(.orange)

            Scrubber(.ruler, value: $value)
                .foregroundStyle(.indigo)

            Scrubber(.emoji, value: $level)
                .scrubberEmoji("🔥")
        }
    }
}

private struct Player: View {
    @State private var position = 81.0
    @State private var isPlaying = true
    var body: some View {
        Scrubber(.squiggle, value: $position, in: 0...214)
            .scrubberAnimating(isPlaying)   // the wave lies flat while paused
            .scrubberLabels { Text(Duration.seconds($0).formatted(.time(pattern: .minuteSecond))) }
    }
}

private struct Editing: View {
    @State private var value = 0.5
    @State private var isScrubbing = false
    var body: some View {
        Scrubber(.glass, value: $value) { editing in
            isScrubbing = editing
        }
        .scrubberHaptics(false)
    }
}

private struct Accessible: View {
    @State private var volume = 0.6
    var body: some View {
        Scrubber(.elastic, value: $volume)
            .accessibilityLabel("Volume")
    }
}

private struct FormRow: View {
    @State private var effort = 6
    var body: some View {
        Form {
            Section("How hard was it?") {
                Scrubber(.effort, value: $effort, in: 1...10)
            }
        }
    }
}

// MARK: - Tests

@MainActor
struct ReadmeSnippetTests {

    private func renders(_ view: some View, _ name: String) {
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 700))
        renderer.scale = 2
        #expect(renderer.cgImage != nil, "\(name) didn't render")
    }

    @Test func everySnippetRenders() {
        renders(OneLine(), "OneLine")
        renders(QuickStart(), "QuickStart")
        renders(EveryStyle(), "EveryStyle")
        renders(Values(), "Values")
        renders(Morphing(), "Morphing")
        renders(Labels(), "Labels")
        renders(Styling(), "Styling")
        renders(Player(), "Player")
        renders(Editing(), "Editing")
        renders(Accessible(), "Accessible")
        renders(FormRow(), "FormRow")
    }

    @Test(arguments: ScrubberStyle.allCases)
    func everyStyleRendersInBothSchemes(_ style: ScrubberStyle) {
        for scheme in [ColorScheme.light, .dark] {
            renders(Scrubber(style, value: .constant(0.4)).environment(\.colorScheme, scheme), "\(style)")
        }
    }

    @Test func everyStyleHasItsWords() {
        for style in ScrubberStyle.allCases {
            #expect(!style.title.isEmpty)
            #expect(!style.summary.isEmpty)
            #expect(!style.inspiration.isEmpty)
            #expect(style.id == style.rawValue)
        }
        #expect(ScrubberStyle.allCases.count == 12)
    }
}
