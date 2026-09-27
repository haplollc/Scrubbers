//
//  ScriptedDemoSnippetTests.swift
//  ScrubbersTests
//
//  The README's scripted-demo snippet, compiled against the Demo SPI and run:
//  a scripted finger drags an elastic scrubber and the bound value follows.
//

import SwiftUI
import Testing
@_spi(Demo) import Scrubbers

@MainActor
struct ScriptedDemoSnippetTests {

    @Test func aScriptedFingerCompilesAndPlaysItsScript() async {
        let finger = ScrubberPuppet()
        let view = Scrubber(.elastic, value: .constant(0.2))
            .scrubberPuppet(finger)
        _ = view

        // Unattached to a scrubber, the finger still plays its script in
        // order and ends lifted.
        #expect(await finger.scrub(from: 0.2, to: 0.9, over: 0.05))
        #expect(finger.fraction == nil)
        #expect(finger.touch?.phase == .up)
    }
}
