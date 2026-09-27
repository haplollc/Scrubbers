//
//  Examples.swift
//  ScrubbersDemo
//
//  Every style set up the way an app would use it: a year ruler, a volume
//  slider, a weight tape, a thermostat in degrees, each in the colour of
//  the design it comes from.
//

import SwiftUI
@_spi(Demo) import Scrubbers

/// One control as an app would set it up.
struct ScrubberExample: Identifiable {
    let style: ScrubberStyle
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil
    var initial: Double = 0.5
    /// What the value means, for the readout.
    var format: @MainActor (Double) -> String = { $0.formatted(.percent.precision(.fractionLength(0))) }
    var labels: (@MainActor (Double) -> Text)? = nil
    var icons: (low: String, high: String)? = nil
    var snapping: ScrubberSnapping = .always
    /// Each style in the colour of the design it comes from.
    var tint: Color? = nil

    var id: ScrubberStyle { style }

    /// The line of code that makes it.
    var code: String { ".\(style.rawValue)" }

    static let all: [ScrubberExample] = ScrubberStyle.allCases.map(example(for:))

    static func example(for style: ScrubberStyle) -> ScrubberExample {
        switch style {
        case .ruler:
            return ScrubberExample(style: .ruler, range: 2007...2026, step: 1, initial: 2016,
                                   format: { String(Int($0.rounded())) },
                                   labels: { Text(String(Int($0.rounded()))) })
        case .elastic:
            return ScrubberExample(style: .elastic, initial: 0.55,
                                   icons: ("speaker.fill", "speaker.wave.3.fill"), tint: .primary)
        case .glass:
            return ScrubberExample(style: .glass, initial: 0.4, tint: .blue)
        case .fluid:
            return ScrubberExample(style: .fluid, range: 0...100, step: 1, initial: 42,
                                   format: { String(Int($0.rounded())) },
                                   tint: Color(red: 0.96, green: 0.31, blue: 0.37))
        case .jelly:
            return ScrubberExample(style: .jelly, initial: 0.7,
                                   tint: Color(red: 1.0, green: 0.45, blue: 0.075))
        case .swing:
            // A budget, in steps of ten dollars.
            return ScrubberExample(style: .swing, range: 0...500, step: 10, initial: 180,
                                   format: { $0.formatted(.currency(code: "USD").precision(.fractionLength(0))) },
                                   labels: { Text($0.formatted(.currency(code: "USD").precision(.fractionLength(0)))) },
                                   tint: .primary)
        case .thermostat:
            // Degrees Fahrenheit, a whole degree a click.
            return ScrubberExample(style: .thermostat, range: 50...90, step: 1, initial: 68,
                                   format: { "\(Int($0.rounded()))°" },
                                   labels: { Text("\(Int($0.rounded()))°") })
        case .emoji:
            return ScrubberExample(style: .emoji, initial: 0.55,
                                   tint: Color(red: 0.88, green: 0.19, blue: 0.42))
        case .mood:
            return ScrubberExample(style: .mood, initial: 0.62,
                                   format: { MoodWords.word(for: $0) })
        case .effort:
            // Apple's scale: one to ten.
            return ScrubberExample(style: .effort, range: 1...10, step: 1, initial: 6,
                                   format: { String(Int($0.rounded())) })
        case .tape:
            // A weight picker, in half kilograms.
            return ScrubberExample(style: .tape, range: 40...120, step: 0.5, initial: 72.5,
                                   format: { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" },
                                   labels: { Text($0.formatted(.number.precision(.fractionLength(0...1)))) },
                                   tint: .orange)
        case .squiggle:
            // A song's seek bar, three and a half minutes long.
            return ScrubberExample(style: .squiggle, range: 0...214, initial: 81,
                                   format: { Duration.seconds($0.rounded()).formatted(.time(pattern: .minuteSecond)) },
                                   labels: { Text(Duration.seconds($0.rounded()).formatted(.time(pattern: .minuteSecond))) },
                                   tint: Color(red: 0.40, green: 0.31, blue: 0.64))
        }
    }
}

/// The seven State of Mind words, for the mood readout.
enum MoodWords {
    static let all = ["Very Unpleasant", "Unpleasant", "Slightly Unpleasant", "Neutral",
                      "Slightly Pleasant", "Pleasant", "Very Pleasant"]
    static func word(for value: Double) -> String {
        all[min(Int(min(max(value, 0), 1) * Double(all.count)), all.count - 1)]
    }
}

/// One example, holding its own value.
struct ScrubberExampleControl: View {
    let example: ScrubberExample
    var puppet: ScrubberPuppet? = nil
    @Binding var value: Double

    var body: some View {
        let control = Scrubber(example.style, value: $value, in: example.range, step: example.step)
            .scrubberSnapping(example.snapping)
            .tint(example.tint)
            .scrubberPuppet(puppet)
            .accessibilityLabel(example.style.title)
            .accessibilityIdentifier("scrubber.\(example.style.rawValue)")
        Group {
            if let icons = example.icons, let labels = example.labels {
                control.scrubberIcons(low: icons.low, high: icons.high).scrubberLabels(labels)
            } else if let icons = example.icons {
                control.scrubberIcons(low: icons.low, high: icons.high)
            } else if let labels = example.labels {
                control.scrubberLabels(labels)
            } else {
                control
            }
        }
    }
}
