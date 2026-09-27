//
//  LiveClock.swift
//  Scrubbers
//
//  A running clock for the styles that move on their own (a wave that
//  travels, a lens that shimmers). It stops while the control is scrolled
//  out of view, while the app is in the background and when Reduce Motion
//  is on, so a screen of idle sliders costs nothing.
//

import SwiftUI

enum LiveClock {
    static let origin = Date()

    static func seconds(at date: Date) -> Double {
        max(0, date.timeIntervalSince(origin))
    }
}

struct LiveTime<Content: View>: View {
    /// Whether the style wants time to run at all right now.
    var running = true
    @ViewBuilder let content: (Double) -> Content

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = true

    var body: some View {
        let live = running && onScreen && scenePhase != .background && !reduceMotion
        TimelineView(.animation(paused: !live)) { timeline in
            content(reduceMotion ? 0 : LiveClock.seconds(at: timeline.date) * ScrubberTime.rate)
        }
        .onViewportVisibilityChange { onScreen = $0 }
    }
}

extension View {
    /// Reports whether any of this view is inside the visible bounds of the
    /// scroll views around it, from the very first layout on, on both axes.
    /// Outside any scroll view it reports true.
    func onViewportVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            let own = CGRect(origin: .zero, size: proxy.size)
            let vertical = proxy.bounds(of: .scrollView(axis: .vertical))
            let horizontal = proxy.bounds(of: .scrollView(axis: .horizontal))
            return (vertical?.intersects(own) ?? true) && (horizontal?.intersects(own) ?? true)
        } action: { visible in
            action(visible)
        }
    }
}
