import SwiftUI

struct InsightsSheetContent: View {
    let zipCode: String?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let zipBundle: ZipLookupResult?
    let metricsSource: MetricsSource?
    let hasActiveSelection: Bool
    let isLoadingSelection: Bool
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
        return zipCode.map { "ZIP \($0)" } ?? AppStrings.Labels.noSelectionTitle
    }

    private var areaSubtitle: String {
        var parts: [String] = []

        if let county = zipBundle?.county?.name, !county.isEmpty {
            parts.append(county)
        }

        if let zipCode {
            parts.append("ZIP \(zipCode)")
        }

        if boundaryScale == .tract, let tractCode = zipBundle?.tract?.tractCode, !tractCode.isEmpty {
            parts.append("Tract \(tractCode)")
        }

        return parts.joined(separator: " · ")
    }

    private var refreshAnimationKey: String {
        let pop = metrics?.population ?? -1
        let income = demographics?.medianHouseholdIncome ?? -1
        let age = demographics?.medianAge ?? -1
        return "\(boundaryScale.rawValue)-\(pop)-\(income)-\(age)"
    }

    private var themeTint: Color {
        boundaryScale.themeColor
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

                    if hasActiveSelection || isLoadingSelection {
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
                        } else if isLoadingSelection && demographics == nil {
                            SelectionStateCard(
                                title: AppStrings.Labels.loadingSelectionTitle,
                                message: AppStrings.Labels.loadingSelectionBody,
                                systemImage: "point.3.connected.trianglepath.dotted",
                                tint: themeTint
                            )
                            KeyMetricsGrid(metrics: metrics)
                            GeneratedInsightsSection(insights: [], isLoading: true)
                        } else {
                            ExpandedInsightsHeaderRow(
                                areaTitle: areaTitle,
                                areaSubtitle: areaSubtitle,
                                zipCode: zipCode,
                                metricsSource: metricsSource,
                                boundaryScale: $boundaryScale
                            )

                            KeyMetricsGrid(metrics: metrics)

                            if let demographics {
                                HousingAffordabilitySection(demographics: demographics, themeTint: themeTint)
                                WorkAndHouseholdSection(demographics: demographics, themeTint: themeTint)
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
