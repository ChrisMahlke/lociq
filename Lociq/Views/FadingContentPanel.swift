//
//  FadingContentPanel.swift
//  Lociq
//
//  Switches between summary and detail demographic content.
//
//  The app uses one content area instead of separate screens. This panel owns
//  the restrained transition between summary metrics and detail rows.
//

import SwiftUI

/// Crossfading content area for summary and detail demographic views.
struct FadingContentPanel: View {
    /// Display-ready demographic snapshot.
    let snapshot: DemographicSnapshot

    /// Whether the detail panel should be visible.
    let isShowingDetails: Bool

    /// Layout metrics for summary and detail content.
    let layout: MinimalLayout

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// Current appearance, shown in the details footer.
    var themePreference: LociqThemePreference = .dark

    /// Changes the appearance from the details footer.
    var onSelectTheme: (LociqThemePreference) -> Void = { _ in }

    /// Renders the active content mode.
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(
                    snapshot: snapshot,
                    layout: layout,
                    themePreference: themePreference,
                    onSelectTheme: onSelectTheme
                )
                .transition(contentTransition)
            } else {
                MetricContent(metrics: snapshot.metrics, layout: layout)
                    .transition(contentTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .animation(LociqMotion.content(reduceMotion: reduceMotion), value: isShowingDetails)
    }

    /// Transition used when swapping content modes.
    ///
    /// The insertion scale is very small by design. It gives the transition a
    /// soft material feel without reading as a slide or navigation change.
    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .topTrailing)),
            removal: .opacity
        )
    }
}

/// Vertical stack of summary metric blocks.
private struct MetricContent: View {
    /// Metrics shown on the primary view.
    let metrics: [DemographicMetric]

    /// Layout metrics controlling vertical rhythm.
    let layout: MinimalLayout

    /// Renders all summary metrics.
    var body: some View {
        VStack(alignment: .trailing, spacing: layout.space(layout.isShortHeight ? 16 : 19)) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// One summary metric block.
///
/// Percentage metrics add a thin bar directly under the value, drawn from the
/// same rounded number the text shows. The detail line then names what the
/// bar and the remainder mean, so color is never the only cue.
private struct MetricBlock: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Display-ready metric.
    let metric: DemographicMetric

    /// Layout metrics for typography.
    let layout: MinimalLayout

    /// Renders title, primary value, optional bar, and secondary detail.
    var body: some View {
        VStack(alignment: .trailing, spacing: layout.space(5)) {
            Text(metric.title)
                .font(LociqTypeScale.metricLabel(layout))
                .foregroundStyle(Color.lociq(.metricLabel))

            Text(metric.primaryValue)
                .font(isPrimaryMetric ? LociqTypeScale.primaryMetricValue(layout) : LociqTypeScale.metricValue(layout))
                .foregroundStyle(Color.lociq(.primary))
                .monospacedDigit()
                .lineLimit(layout.usesSingleColumn ? 2 : 1)
                .minimumScaleFactor(layout.usesSingleColumn ? 1 : 0.78)
                .allowsTightening(true)

            if let fraction = metric.barFraction {
                MetricBar(fraction: fraction, isEmphasized: reduceTransparency)
                    .frame(width: min(layout.contentWidth, layout.scaled(164, relativeTo: .body)), height: 3 * layout.graphicScale)
                    .padding(.vertical, layout.space(2))
            }

            if !metric.detail.isEmpty {
                Text(metric.detail)
                    .font(LociqTypeScale.metricDetail(layout))
                    .foregroundStyle(Color.lociq(.secondary))
                    .lineLimit(layout.usesSingleColumn ? nil : 2)
                    .minimumScaleFactor(layout.usesSingleColumn ? 1 : 0.82)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilitySummary)
        .accessibilityIdentifier("metric.\(metric.id)")
    }

    /// Population is the main figure and gets one size step more.
    private var isPrimaryMetric: Bool {
        metric.resolvedKind == .population
    }
}
