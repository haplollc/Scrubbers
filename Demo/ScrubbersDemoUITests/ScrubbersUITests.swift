//
//  ScrubbersUITests.swift
//  ScrubbersDemoUITests
//
//  End to end: launches the real app on the Scrubbers page and drags every
//  style with a real touch, the way a person would, then reads back the value
//  the control reports to VoiceOver and the readout beside it. Nothing is
//  stubbed.
//

import XCTest

final class ScrubbersUITests: XCTestCase {

    /// How each style is dragged: from and to, as fractions of the control's
    /// frame. The tape is dragged leftward (the scale moves under a fixed
    /// needle), the thermostat round its ring.
    private static let drags: [(style: String, up: (CGVector, CGVector), down: (CGVector, CGVector))] = [
        ("ruler", (v(0.45, 0.5), v(0.85, 0.5)), (v(0.85, 0.5), v(0.2, 0.5))),
        ("glass", (v(0.4, 0.5), v(0.9, 0.5)), (v(0.9, 0.5), v(0.15, 0.5))),
        ("jelly", (v(0.7, 0.8), v(0.92, 0.8)), (v(0.92, 0.8), v(0.3, 0.8))),
        ("elastic", (v(0.3, 0.5), v(0.8, 0.5)), (v(0.8, 0.5), v(0.25, 0.5))),
        ("fluid", (v(0.42, 0.78), v(0.85, 0.78)), (v(0.85, 0.78), v(0.2, 0.78))),
        ("squiggle", (v(0.38, 0.5), v(0.8, 0.5)), (v(0.8, 0.5), v(0.2, 0.5))),
        ("thermostat", (v(0.2, 0.5), v(0.5, 0.1)), (v(0.5, 0.1), v(0.2, 0.55))),
        ("swing", (v(0.36, 0.85), v(0.8, 0.85)), (v(0.8, 0.85), v(0.2, 0.85))),
        ("mood", (v(0.62, 0.88), v(0.95, 0.88)), (v(0.95, 0.88), v(0.1, 0.88))),
        ("tape", (v(0.7, 0.7), v(0.3, 0.7)), (v(0.3, 0.7), v(0.75, 0.7))),
        ("effort", (v(0.55, 0.8), v(0.95, 0.8)), (v(0.95, 0.8), v(0.1, 0.8))),
        ("emoji", (v(0.55, 0.74), v(0.9, 0.74)), (v(0.9, 0.74), v(0.2, 0.74))),
    ]

    private static func v(_ x: CGFloat, _ y: CGFloat) -> CGVector { CGVector(dx: x, dy: y) }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testEveryStyleFollowsARealDrag() throws {
        for drag in Self.drags {
            let app = XCUIApplication()
            app.launchEnvironment["SCRUBBERS_SCROLL"] = drag.style
            app.launch()

            let control = app.descendants(matching: .any)["scrubber.\(drag.style)"]
            XCTAssertTrue(control.waitForExistence(timeout: 10), "\(drag.style): no control")
            let readout = app.staticTexts["value.\(drag.style)"]
            XCTAssertTrue(readout.waitForExistence(timeout: 5), "\(drag.style): no readout")

            let start = control.value as? String ?? ""
            let startReadout = readout.label

            swipe(control, drag.up)
            let afterUp = control.value as? String ?? ""
            let readoutUp = readout.label

            swipe(control, drag.down)
            let afterDown = control.value as? String ?? ""

            print("[scrubbers-e2e] \(drag.style): \(start) → \(afterUp) → \(afterDown)  readout \(startReadout) → \(readoutUp)")
            XCTAssertNotEqual(start, afterUp, "\(drag.style): the first drag didn't change the value")
            XCTAssertNotEqual(afterUp, afterDown, "\(drag.style): the drag back didn't change the value")
            XCTAssertNotEqual(startReadout, readoutUp, "\(drag.style): the readout didn't follow the control")
            app.terminate()
        }
    }

    /// To VoiceOver every style is a standard slider, reading the same text
    /// the control shows: a year, a price, a word for a feeling.
    @MainActor
    func testEveryStyleReadsAsASliderToVoiceOver() throws {
        let expected: [(style: String, value: String)] = [
            ("ruler", "2016"), ("glass", "40%"), ("thermostat", "68°"), ("swing", "$180"),
            ("mood", "Slightly Pleasant"), ("tape", "72.5"), ("squiggle", "1:21"), ("effort", "6"),
        ]
        for (style, value) in expected {
            let app = XCUIApplication()
            app.launchEnvironment["SCRUBBERS_SCROLL"] = style
            app.launch()
            let slider = app.sliders["scrubber.\(style)"]
            XCTAssertTrue(slider.waitForExistence(timeout: 10), "\(style) isn't a slider to VoiceOver")
            print("[scrubbers-e2e] \(style) reads as slider: \(slider.value as? String ?? "nil")")
            XCTAssertEqual(slider.value as? String, value)
            app.terminate()
        }
    }

    @MainActor
    private func swipe(_ element: XCUIElement, _ path: (CGVector, CGVector)) {
        let from = element.coordinate(withNormalizedOffset: path.0)
        let to = element.coordinate(withNormalizedOffset: path.1)
        from.press(forDuration: 0.12, thenDragTo: to, withVelocity: 600, thenHoldForDuration: 0.25)
        // Let the release settle (springs, coasting) before reading.
        Thread.sleep(forTimeInterval: 1.2)
    }
}
