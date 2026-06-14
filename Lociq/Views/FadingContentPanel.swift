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

    /// Renders the active content mode.
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(snapshot: snapshot, layout: layout)
                    .opacity(DemographicContentStyle.detailPanelOpacity)
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
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 18 : 22) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// One summary metric block.
private struct MetricBlock: View {
    /// Display-ready metric.
    let metric: DemographicMetric

    /// Layout metrics for typography.
    let layout: MinimalLayout

    /// Renders title, primary value, and secondary detail.
    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(metric.title)
                .font(LociqTypeScale.metricLabel(layout))
                .foregroundStyle(Color.lociqText.opacity(0.78))

            Text(metric.primaryValue)
                .font(LociqTypeScale.metricValue(layout))
                .foregroundStyle(Color.lociqText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)

            Text(metric.detail)
                .font(LociqTypeScale.metricDetail(layout))
                .foregroundStyle(Color.lociqText.opacity(0.54))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
