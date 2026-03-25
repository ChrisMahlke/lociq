import SwiftUI

struct InsightsSheetContent: View {
    let zipCode: String?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let zipBundle: ZipLookupResult?
    let metricsSource: MetricsSource?
    @Binding var boundaryScale: BoundaryOverlayScale
    @Binding var sheetOffset: CGFloat

    @State private var hintVisible: Bool = true

    private var insights: [Insight] { zipBundle?.insights ?? [] }

    private var isCollapsed: Bool { sheetOffset < 300 }

    private var zipLine: String {
        guard let zipCode else { return AppStrings.Symbols.emDash }
        return zipCode
    }

    private var refreshAnimationKey: String {
        let pop = metrics?.population ?? -1
        let income = demographics?.medianHouseholdIncome ?? -1
        let age = demographics?.medianAge ?? -1
        return "\(boundaryScale.rawValue)-\(pop)-\(income)-\(age)"
    }

    private var themeTint: Color {
        switch boundaryScale {
        case .zip: return .blue
        case .tract: return .orange
        }
    }

    var body: some View {
        Group {
            if isCollapsed {
                VStack(alignment: .leading, spacing: 10) {
                    CollapsedInsightsHeaderRow(
                        zipLine: zipLine,
                        boundaryScale: $boundaryScale,
                        hintVisible: hintVisible
                    )

                    CollapsedInsightsMetricsGrid(metrics: metrics)
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ExpandedInsightsHeaderRow(
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
