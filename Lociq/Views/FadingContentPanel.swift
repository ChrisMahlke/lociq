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
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 16 : 19) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// One summary metric block.
private struct MetricBlock: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                .lineLimit(layout.usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(layout.usesAccessibilityLayout ? 1 : 0.78)
                .allowsTightening(true)

            if !metric.detail.isEmpty {
                Text(metric.detail)
                    .font(LociqTypeScale.metricDetail(layout))
                    .foregroundStyle(Color.lociqText.opacity(0.54))
                    .lineLimit(layout.usesAccessibilityLayout ? nil : 2)
                    .minimumScaleFactor(layout.usesAccessibilityLayout ? 1 : 0.82)
                    .multilineTextAlignment(.trailing)
            }

            if let progress = barProgress {
                metricBar(progress: progress)
                    .frame(width: min(layout.contentWidth, 164), height: 3)
                    .padding(.top, 2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(metric.title == "OWNER OCCUPIED" ? "Housing tenure" : "Education attainment")
                    .accessibilityValue(metric.accessibilitySummary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilitySummary)
    }

    /// Both bars represent their visible primary percentage.
    private var barProgress: Double? {
        metric.progress
    }

    @ViewBuilder
    private func metricBar(progress: Double) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            if metric.title == "OWNER OCCUPIED" || metric.title == "EDUCATION" {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.lociqText.opacity(reduceTransparency ? 0.26 : 0.13))
                    Rectangle()
                        .fill(Color.lociqText.opacity(reduceTransparency ? 0.72 : 0.48))
                        .frame(width: width * progress)
                }
                .accessibilityHidden(true)
            }
        }
    }
}
