import SwiftUI

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white.opacity(0.45), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width * 0.55)
                    .rotationEffect(.degrees(18))
                    .offset(x: geo.size.width * phase)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct InsightLoadingPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                InsightSkeletonCard()
            }
        }
    }
}

private struct InsightSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 20, height: 20)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 10)
            }

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.secondary.opacity(0.24))
                .frame(height: 12)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 6)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 9)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.9)
        )
        .shimmer()
    }
}

struct BoundaryScaleIconToggle: View {
    @Binding var scale: BoundaryOverlayScale

    private var options: [BoundaryOverlayScale] {
        [.zip, .tract]
    }

    private func activeColor(for option: BoundaryOverlayScale) -> Color {
        option.themeColor
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    scale = option
                } label: {
                    let isSelected = scale == option
                    let color = activeColor(for: option)

                    Text(option.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? color : .primary.opacity(0.72))
                        .frame(minWidth: 54)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? color.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? color.opacity(0.42) : Color.primary.opacity(0.10), lineWidth: 0.9)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(scale == option ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.94))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct KeyMetricsGrid: View {
    let metrics: CensusMetrics?

    private var isLoading: Bool { metrics == nil }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            MetricTile(
                title: AppStrings.Metrics.population,
                value: metrics.map { InsightsFormatting.number($0.population) },
                systemImage: IconNames.person,
                loading: isLoading
            )
            MetricTile(
                title: AppStrings.Metrics.medianIncome,
                value: metrics.map { InsightsFormatting.currency($0.medianIncome) },
                systemImage: IconNames.money,
                loading: isLoading
            )
            MetricTile(
                title: AppStrings.Metrics.medianAge,
                value: metrics.flatMap { metric in
                    metric.medianAge.map { String(format: AppStrings.Symbols.oneDecimalFormat, $0) }
                },
                systemImage: IconNames.clock,
                loading: isLoading
            )
            MetricTile(
                title: AppStrings.Metrics.households,
                value: metrics.map { InsightsFormatting.number($0.households) },
                systemImage: IconNames.house,
                loading: isLoading
            )
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String?
    let systemImage: String
    let loading: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if loading {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Text(value ?? AppStrings.Symbols.emDash)
                        .id(value ?? AppStrings.Symbols.emDash)
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        .animation(.easeInOut(duration: 0.22), value: value)
        .animation(.easeInOut(duration: 0.22), value: loading)
    }
}

struct CollapsedMetricChip: View {
    let icon: String
    let label: String
    let value: String?
    let loading: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if loading {
                    ProgressView()
                        .scaleEffect(0.75)
                } else if let value = value {
                    Text(value)
                        .id(value)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    Text(AppStrings.Symbols.emDash)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule()
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            Capsule()
                .stroke(Color.accentColor.opacity(0.14), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .animation(.easeInOut(duration: 0.2), value: value)
    }
}

struct SwipeUpHint: View {
    @State private var bounce = false

    var body: some View {
        Image(systemName: IconNames.chevronUp)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
            .opacity(0.9)
            .offset(y: bounce ? -1 : 1)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bounce)
            .onAppear { bounce = true }
            .accessibilityLabel(AppStrings.Labels.swipeUpForMoreData)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.98),
                    Color(.secondarySystemGroupedBackground).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

struct InsightRedesignPanel: View {
    let insights: [Insight]
    @State private var animateCards = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                InsightVisualCard(insight: insight)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 8)
                    .animation(
                        .spring(response: 0.36, dampingFraction: 0.88)
                            .delay(Double(index) * 0.04),
                        value: animateCards
                    )
            }
        }
        .onAppear { animateCards = true }
    }
}

private struct InsightVisualCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: symbol(for: insight.category))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color(for: insight.category))
                    .frame(width: 20, height: 20)
                    .background(color(for: insight.category).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(label(for: insight.category))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.9)
                        .clipped()
                    Text(insight.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.8)
                        .clipped()
                }

                Spacer(minLength: 0)
            }

            Text(insight.detail)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.72))
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.75)
                .clipped()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [color(for: insight.category).opacity(0.14), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(severityColor(for: insight.severity).opacity(0.24), lineWidth: 0.9)
        )
    }

    private func symbol(for category: Insight.Category) -> String {
        switch category {
        case .housing: return IconNames.houseFilled
        case .affordability: return IconNames.affordabilityFilled
        case .mobility: return IconNames.mobilityFilled
        case .demographics: return IconNames.demographicsFilled
        case .governance: return IconNames.servicesFilled
        case .geography: return IconNames.mapFilled
        }
    }

    private func label(for category: Insight.Category) -> String {
        switch category {
        case .housing: return AppStrings.Labels.housing
        case .affordability: return AppStrings.Labels.affordability
        case .mobility: return AppStrings.Labels.mobility
        case .demographics: return AppStrings.Labels.demographics
        case .governance: return AppStrings.Labels.services
        case .geography: return AppStrings.Labels.geography
        }
    }

    private func color(for category: Insight.Category) -> Color {
        switch category {
        case .housing: return .blue
        case .affordability: return .orange
        case .mobility: return .mint
        case .demographics: return .purple
        case .governance: return .indigo
        case .geography: return .teal
        }
    }

    private func severityColor(for severity: Insight.Severity) -> Color {
        switch severity {
        case .neutral: return .secondary
        case .positive: return .green
        case .caution: return .orange
        }
    }
}

struct InfographicBadge: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 0.8)
        )
    }
}

struct OccupancySplitBar: View {
    let ownerText: String
    let renterText: String
    let ownerShare: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStrings.Labels.occupancyMix)
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.blue.gradient)
                        .frame(width: geometry.size.width * ownerShare)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.orange.gradient)
                }
            }
            .frame(height: 12)

            HStack {
                Label(ownerText, systemImage: IconNames.houseFilled)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Label(renterText, systemImage: IconNames.keyFilled)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct MiniRingStat: View {
    let label: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .id(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .monospacedDigit()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.35), value: progress)
        .animation(.easeInOut(duration: 0.22), value: value)
    }
}

struct CompositionRow: View {
    let label: String
    let countText: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(countText)
                    .id(countText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: geometry.size.width * progress)
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
            }
            .frame(height: 8)
        }
        .animation(.easeInOut(duration: 0.22), value: countText)
    }
}
