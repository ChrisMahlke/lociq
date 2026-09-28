//
//  WatchComplicationGallery.swift
//  LociqWatch
//
//  Debug-only screen that draws every complication family, for design review.
//
//  `--lociq-complication-gallery` shows it in place of the app, with the
//  loaded city (use it with `--lociq-ui-fixture`). Complications on a real
//  watch face are also tinted by the face; this shows their layout.
//

#if DEBUG
import SwiftUI
import WidgetKit

/// Every complication family, drawn at typical sizes for the loaded city.
struct WatchComplicationGallery: View {
    /// True when the launch arguments ask for the gallery.
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--lociq-complication-gallery")
    }

    let viewState: LocationProfileViewState

    /// The outline the app built for the displayed city.
    let glyph: BoundaryGlyph?

    var body: some View {
        let now = Date()
        let entry = CityComplicationEntry(
            date: now,
            snapshot: ComplicationSnapshot(viewState: viewState, glyph: glyph, confirmedAt: now)
        )
        let yesterday = CityComplicationEntry(
            date: now,
            snapshot: ComplicationSnapshot(viewState: viewState, glyph: glyph, confirmedAt: now.addingTimeInterval(-86_400))
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sample("RECTANGULAR", CityComplicationView(entry: entry, family: .accessoryRectangular), size: CGSize(width: 170, height: 56))
                HStack(spacing: 14) {
                    sample("CIRCULAR", CityComplicationView(entry: entry, family: .accessoryCircular), size: CGSize(width: 50, height: 50))
                    sample("CORNER", CityComplicationView(entry: entry, family: .accessoryCorner), size: CGSize(width: 40, height: 40))
                }
                sample("INLINE", CityComplicationView(entry: entry, family: .accessoryInline), size: CGSize(width: 170, height: 20))
                sample("A DAY LATER", CityComplicationView(entry: yesterday, family: .accessoryRectangular), size: CGSize(width: 170, height: 56))
                HStack(spacing: 14) {
                    sample("CIRCULAR", CityComplicationView(entry: yesterday, family: .accessoryCircular), size: CGSize(width: 50, height: 50))
                    sample("INLINE", CityComplicationView(entry: yesterday, family: .accessoryInline), size: CGSize(width: 100, height: 20))
                }
                sample("EMPTY", CityComplicationView(entry: CityComplicationEntry(date: now, snapshot: nil), family: .accessoryRectangular), size: CGSize(width: 170, height: 40))
            }
            .padding(.horizontal, 4)
        }
    }

    private func sample(_ name: String, _ view: some View, size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            view
                .frame(width: size.width, height: size.height)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        }
    }
}
#endif
