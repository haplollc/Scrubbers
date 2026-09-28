//
//  ScrubbersDemoApp.swift
//  ScrubbersDemo
//
//  The gallery of every style, plus two stages the scripts record:
//  SCRUBBERS_DEMO=1 for the hero video (SCRUBBERS_STATUSBAR=1 to keep the
//  status bar, for a phone-framed cut), SCRUBBERS_MEDIA=<style> (with
//  SCRUBBERS_SCHEME=dark for the dark variants) for the README's GIFs.
//

import SwiftUI
import Scrubbers

@main
struct ScrubbersDemoApp: App {
    private static let env = ProcessInfo.processInfo.environment

    var body: some Scene {
        WindowGroup {
            if Self.env["SCRUBBERS_DEMO"] == "1" {
                // SCRUBBERS_STATUSBAR=1 keeps the status bar, for a video
                // shown inside a phone frame.
                DemoStage()
                    .statusBarHidden(Self.env["SCRUBBERS_STATUSBAR"] != "1")
            } else if let name = Self.env["SCRUBBERS_MEDIA"], let style = ScrubberStyle(rawValue: name) {
                MediaStage(example: .example(for: style), dark: Self.env["SCRUBBERS_SCHEME"] == "dark")
                    .statusBarHidden(true)
            } else {
                NavigationStack {
                    Gallery()
                        .navigationTitle("Scrubbers")
                }
            }
        }
    }
}
