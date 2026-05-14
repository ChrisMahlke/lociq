//
//  FadingContentPanel.swift
//  Lociq
//
//  Switches between summary and detail demographic content.
//

import SwiftUI

struct FadingContentPanel: View {
    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool
    let layout: MinimalLayout
    let reduceMotion: Bool

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

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .topTrailing)),
            removal: .opacity
        )
    }
}

private struct MetricContent: View {
    let metrics: [DemographicMetric]
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 18 : 22) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct MetricBlock: View {
    let metric: DemographicMetric
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(metric.title)
                .font(LociqTypeScale.metricLabel(layout))
                .foregroundStyle(.white.opacity(0.78))

            Text(metric.primaryValue)
                .font(LociqTypeScale.metricValue(layout))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)

            Text(metric.detail)
                .font(LociqTypeScale.metricDetail(layout))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
