//
//  Gallery.swift
//  ScrubbersDemo
//
//  Every style, live, in one scrolling list: its name, the case you pass,
//  and the value it holds, above the control itself.
//
//  SCRUBBERS_SCROLL=<style> opens the list scrolled to that style.
//

import SwiftUI
import Scrubbers

struct Gallery: View {
    @State private var values: [ScrubberStyle: Double] =
        Dictionary(uniqueKeysWithValues: ScrubberExample.all.map { ($0.style, $0.initial) })

    private static let env = ProcessInfo.processInfo.environment

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ScrubberExample.all) { example in
                        row(example)
                            .id(example.style)
                        if example.style != ScrubberExample.all.last?.style {
                            Divider().padding(.leading, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .onAppear {
                if let name = Self.env["SCRUBBERS_SCROLL"], let style = ScrubberStyle(rawValue: name) {
                    proxy.scrollTo(style, anchor: .top)
                }
            }
        }
    }

    private func row(_ example: ScrubberExample) -> some View {
        let binding = Binding(
            get: { values[example.style] ?? example.initial },
            set: { values[example.style] = $0 }
        )
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(example.style.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(example.code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(example.format(binding.wrappedValue))
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("value.\(example.style.rawValue)")
            }
            ScrubberExampleControl(example: example, value: binding)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

#Preview {
    NavigationStack { Gallery() }
}
