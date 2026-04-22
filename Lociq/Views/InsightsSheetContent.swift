import SwiftUI

struct InsightsSheetContent: View {
    let zipCode: String?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let zipBundle: ZipLookupResult?
    let metricsSource: MetricsSource?
    let hasActiveSelection: Bool
    let isLoadingSelection: Bool
    let selectionFeedbackState: SelectionFeedbackState?
    let isRefreshingScale: Bool
    let onRetrySelection: () -> Void
    @Binding var boundaryScale: BoundaryOverlayScale
    @Binding var sheetOffset: CGFloat

    @State private var hintVisible: Bool = true

    private var insights: [Insight] { zipBundle?.insights ?? [] }

    private var isCollapsed: Bool { sheetOffset < 300 }

    private var zipLine: String {
        guard let zipCode else { return AppStrings.Symbols.emDash }
        return zipCode
    }

    private var areaTitle: String {
        if let place = zipBundle?.place?.name, !place.isEmpty {
            return place
        }
        if let demographics, !demographics.name.isEmpty {
            return demographics.name
        }
        return zipCode.map(AppStrings.Formats.zip) ?? AppStrings.Labels.noSelectionTitle
    }

    private var areaSubtitle: String {
        var parts: [String] = []

        if let county = zipBundle?.county?.name, !county.isEmpty {
            parts.append(county)
        }

        if let zipCode {
            parts.append(AppStrings.Formats.zip(zipCode))
        }

        if boundaryScale == .tract, let tractCode = zipBundle?.tract?.tractCode, !tractCode.isEmpty {
            parts.append(AppStrings.Formats.tract(tractCode))
        }

        return parts.joined(separator: " · ")
    }

    private var refreshAnimationKey: String {
        let pop = metrics?.population ?? -1
        let income = demographics?.medianHouseholdIncome ?? -1
        let age = demographics?.medianAge ?? -1
        let area = zipBundle?.place?.name ?? zipBundle?.tract?.geoid ?? zipCode ?? "none"
        return "\(boundaryScale.rawValue)-\(area)-\(pop)-\(income)-\(age)"
    }

    private var themeTint: Color {
        boundaryScale.themeColor
    }

    private var isFallbackToZIP: Bool {
        boundaryScale == .tract && metricsSource == .zcta
    }

    private var showsNoCoverageState: Bool {
        selectionFeedbackState == .noCoverage
    }

    private var showsSampleFallbackState: Bool {
        selectionFeedbackState == .sampleFallback
    }

    var body: some View {
        Group {
            if isCollapsed {
                VStack(alignment: .leading, spacing: 10) {
                    CollapsedInsightsHeaderRow(
                        areaTitle: areaTitle,
                        areaSubtitle: areaSubtitle,
                        zipLine: zipLine,
                        boundaryScale: $boundaryScale,
                        hintVisible: hintVisible,
                        hasActiveSelection: hasActiveSelection
                    )

                    if showsNoCoverageState {
                        CompactSelectionFeedbackCard(
                            title: AppStrings.Labels.noCoverageTitle,
                            message: AppStrings.Labels.noCoverageBody,
                            systemImage: "mappin.slash.circle.fill",
                            tint: .orange
                        )
                    } else if showsSampleFallbackState {
                        CompactSelectionFeedbackCard(
                            title: AppStrings.Labels.sampleFallbackTitle,
                            message: AppStrings.Labels.sampleFallbackBody,
                            systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                            tint: .indigo
                        )
                    } else if hasActiveSelection || isLoadingSelection {
                        CollapsedInsightsMetricsGrid(metrics: metrics)
                    } else {
                        CompactSheetPromptCard()
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if !hasActiveSelection {
                            SelectionStateCard(
                                title: AppStrings.Labels.noSelectionTitle,
                                message: AppStrings.Labels.noSelectionBody,
                                systemImage: "hand.tap.fill",
                                tint: .blue
                            )
                        } else if showsNoCoverageState {
                            SelectionStateCard(
                                title: AppStrings.Labels.noCoverageTitle,
                                message: AppStrings.Labels.noCoverageBody,
                                systemImage: "mappin.slash.circle.fill",
                                tint: .orange
                            )
                        } else if isLoadingSelection && demographics == nil && metrics == nil {
                            SelectionStateCard(
                                title: AppStrings.Labels.loadingSelectionTitle,
                                message: AppStrings.Labels.loadingSelectionBody,
                                systemImage: "point.3.connected.trianglepath.dotted",
                                tint: themeTint
                            )
                            KeyMetricsGrid(metrics: metrics)
                            GeneratedInsightsSection(insights: [], isLoading: true)
                        } else if showsSampleFallbackState {
                            SelectionStateCard(
                                title: AppStrings.Labels.sampleFallbackTitle,
                                message: AppStrings.Labels.sampleFallbackBody,
                                systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                                tint: .indigo,
                                actionTitle: AppStrings.Labels.retry,
                                action: onRetrySelection
                            )

                            if let metrics {
                                KeyMetricsGrid(metrics: metrics)
                            }
                        } else {
                            if isRefreshingScale {
                                InlineSelectionRefreshCard(
                                    title: AppStrings.Formats.refreshingScale(boundaryScale.displayTitle),
                                    message: AppStrings.Labels.refreshingScaleBody,
                                    tint: themeTint
                                )
                            }

                            ExpandedInsightsHeaderRow(
                                areaTitle: areaTitle,
                                areaSubtitle: areaSubtitle,
                                zipCode: zipCode,
                                metricsSource: metricsSource,
                                isFallbackToZIP: isFallbackToZIP,
                                boundaryScale: $boundaryScale
                            )
                            .id("header-\(refreshAnimationKey)")
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            KeyMetricsGrid(metrics: metrics)
                                .id("metrics-\(refreshAnimationKey)")
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                            if let demographics {
                                QuickSignalsSection(demographics: demographics, themeTint: themeTint)
                                HousingAffordabilitySection(demographics: demographics, themeTint: themeTint)
                                DemographicCompositionSection(
                                    demographics: demographics,
                                    totalPopulation: metrics?.population,
                                    themeTint: themeTint
                                )
                            }

                            if zipBundle != nil {
                                GeneratedInsightsSection(insights: insights, isLoading: false)
                            } else if metrics == nil {
                                GeneratedInsightsSection(insights: [], isLoading: true)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.25)) { hintVisible = false }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: refreshAnimationKey)
    }
}
