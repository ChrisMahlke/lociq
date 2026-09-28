//
//  WatchProfilePages.swift
//  LociqWatch
//
//  Renders a loaded city profile as vertical pages turned with the Digital Crown.
//
//  The pages follow the iPhone summary: the place and its outline, the people,
//  homes and education, then the details and the source. Each is one quiet
//  screen of type, with the thin bars and the uniform outline treatment the
//  iPhone uses, and no extra graphics.
//

import SwiftUI

/// The loaded profile's pages and the refresh control.
struct WatchProfilePages: View {
    /// Display snapshot, including any refresh confirmation.
    let snapshot: DemographicSnapshot

    /// View state for the outline, marker, and dimming.
    let viewState: LocationProfileViewState

    /// Outline for the displayed place, when built.
    let glyph: BoundaryGlyph?

    /// Restarts the outline trace when the place changes.
    let traceToken: Int

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// The refresh button, when refreshing can help.
    let refresh: WatchRefreshAction?

    /// The page on screen.
    @State private var page = WatchProfilePages.initialPage

    var body: some View {
        TabView(selection: $page) {
            WatchPlacePage(
                snapshot: snapshot,
                viewState: viewState,
                glyph: glyph,
                traceToken: traceToken,
                reduceMotion: reduceMotion
            )
            // Refresh belongs to the place. It sits in the empty corner
            // beside the time, so the outline keeps the page's height.
            .toolbar {
                if let refresh {
                    ToolbarItem(placement: .topBarLeading) {
                        WatchRefreshButton(action: refresh)
                    }
                }
            }
            .tag(0)

            WatchMetricsPage(metrics: metrics([.population, .income, .households]))
                .tag(1)

            WatchMetricsPage(metrics: metrics([.ownerOccupied, .education]))
                .tag(2)

            WatchDetailsPage(snapshot: snapshot)
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
        .opacity(viewState.isContentDimmed ? 0.45 : 1)
        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isContentDimmed)
    }

    /// Summary metrics of the given kinds, in that order.
    private func metrics(_ kinds: [DemographicMetricKind]) -> [DemographicMetric] {
        kinds.compactMap { kind in snapshot.metrics.first { $0.resolvedKind == kind } }
    }

    /// The first page shown: the place, or in Debug builds the page that
    /// `--lociq-watch-page <0-3>` asks for, for screenshots.
    private static var initialPage: Int {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--lociq-watch-page"),
           arguments.indices.contains(index + 1),
           let page = Int(arguments[index + 1]), (0...3).contains(page) {
            return page
        }
        #endif
        return 0
    }
}

/// First page: the city's outline with the location marker, the city, and its density.
///
/// The outline takes all the height the text leaves, so it is as large as the
/// watch allows while the city name stays whole.
private struct WatchPlacePage: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let snapshot: DemographicSnapshot
    let viewState: LocationProfileViewState
    let glyph: BoundaryGlyph?
    let traceToken: Int
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 6) {
            if viewState.canShowBoundary, let glyph {
                GeometryReader { proxy in
                    let frame = CGSize(width: proxy.size.width * 0.8, height: proxy.size.height)
                    let size = glyph.fittedSize(within: frame)
                    CityBoundaryPreview(
                        glyph: glyph,
                        coordinate: viewState.coordinate,
                        horizontalAccuracy: viewState.horizontalAccuracy,
                        isApproximate: viewState.isApproximate,
                        densityPerSquareMile: snapshot.densityPerSquareMile,
                        traceToken: traceToken,
                        // Always On shows the finished outline, without motion.
                        reduceMotion: reduceMotion || isLuminanceReduced,
                        graphicScale: 0.85,
                        markerFrameSize: frame
                    )
                    .frame(width: size.width, height: size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Spacer(minLength: 0)
            }

            VStack(spacing: 2) {
                Text(snapshot.market)
                    .font(WatchTypeScale.city)
                    .foregroundStyle(Color.lociq(.primary))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)

                if !snapshot.statusLine.isEmpty {
                    Text(snapshot.statusLine)
                        .font(WatchTypeScale.status)
                        .foregroundStyle(Color.lociq(.status))
                        .lineLimit(2)
                }

                if let density = snapshot.densityPerSquareMile {
                    (Text("DENSITY ").foregroundStyle(Color.lociq(.secondary))
                        + Text(CityDensityCalculator.formatted(density)).foregroundStyle(Color.lociq(.densityValue)))
                        .font(WatchTypeScale.detail)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel("Population density")
                        .accessibilityValue(CityDensityCalculator.spoken(density))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A page of summary metrics, stacked like the iPhone summary.
private struct WatchMetricsPage: View {
    let metrics: [DemographicMetric]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(metrics) { metric in
                    WatchMetricBlock(metric: metric)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Keeps text clear of the screen edge and the page indicator.
            .padding(.leading, 4)
            .padding(.trailing, 10)
        }
    }
}

/// One summary metric: label, value, an optional bar, and its detail line.
///
/// Bars are drawn from the same rounded number the text shows, and the
/// detail line names what the remainder means, so color is never the only cue.
private struct WatchMetricBlock: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let metric: DemographicMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metric.title)
                .font(WatchTypeScale.label)
                .foregroundStyle(Color.lociq(.metricLabel))

            Text(metric.primaryValue)
                .font(metric.resolvedKind == .population ? WatchTypeScale.primaryValue : WatchTypeScale.value)
                .foregroundStyle(Color.lociq(.primary))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let fraction = metric.barFraction {
                MetricBar(fraction: fraction, isEmphasized: reduceTransparency)
                    .frame(height: 3)
                    .padding(.vertical, 3)
            }

            if !metric.detail.isEmpty {
                Text(metric.detail)
                    .font(WatchTypeScale.detail)
                    .foregroundStyle(Color.lociq(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilitySummary)
    }
}

/// Last page: age, housing, and commuting, then the source and the Census notice.
private struct WatchDetailsPage: View {
    let snapshot: DemographicSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(snapshot.detailSections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(WatchTypeScale.detail)
                            .foregroundStyle(Color.lociq(.sectionTitle))
                            .accessibilityAddTraits(.isHeader)

                        ForEach(section.rows) { row in
                            WatchDetailRow(row: row)
                        }
                    }
                }

                WatchSourceFooter(dataVintage: snapshot.dataVintage)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Keeps text clear of the screen edge, and right-aligned values
            // clear of the page indicator.
            .padding(.leading, 4)
            .padding(.trailing, 10)
        }
    }
}

/// One label/value row. The value never breaks; the label stacks above it
/// when the two do not fit side by side.
private struct WatchDetailRow: View {
    let row: DemographicDetailRow

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                label
                    .lineLimit(1)
                    .fixedSize()
                value
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 0) {
                label
                    .fixedSize(horizontal: false, vertical: true)
                value
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
    }

    private var label: some View {
        Text(row.label)
            .font(WatchTypeScale.detail)
            .foregroundStyle(Color.lociq(.detailLabel))
    }

    private var value: some View {
        Text(row.value)
            .font(WatchTypeScale.detailValue)
            .foregroundStyle(Color.lociq(.detailValue))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Source, data years, and the Census Data API notice.
private struct WatchSourceFooter: View {
    let dataVintage: String?

    var body: some View {
        let vintage = CensusDataVintage(identifier: dataVintage)
        VStack(alignment: .leading, spacing: 3) {
            Text("SOURCE · U.S. CENSUS BUREAU")
            Text(vintage?.sourceLabel ?? "ACS 5-YEAR ESTIMATES")
            Text(CensusAttribution.apiNotice)
                .foregroundStyle(Color.lociq(.secondary))
                .padding(.top, 2)
        }
        .font(WatchTypeScale.detail)
        .foregroundStyle(Color.lociq(.detailLabel))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Corner refresh button; a spinner replaces it while a refresh runs.
private struct WatchRefreshButton: View {
    let action: WatchRefreshAction

    var body: some View {
        Button(action: action.perform) {
            if action.isBusy {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(action.isBusy)
        .accessibilityLabel(action.isBusy ? "Refreshing" : "Refresh")
        .accessibilityHint("Finds your location and reloads Census data")
    }
}
