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
            parts.append("Neighborhood \(tractCode)")
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
                            KeyMetricsGrid(metrics: metrics, demographics: demographics)
                        } else {
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

                            KeyMetricsGrid(metrics: metrics, demographics: demographics)
                                .id("metrics-\(refreshAnimationKey)")
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                            if let demographics {
                                HousingAffordabilitySection(demographics: demographics)
                                DemographicCompositionSection(
                                    demographics: demographics,
                                    totalPopulation: metrics?.population,
                                    themeTint: themeTint
                                )
                                if let zipCode {
                                    SchoolsPreviewSection(zipCode: zipCode, themeTint: themeTint)
                                }
                            }
                        }
                    }
                    .padding(.bottom, BottomRibbonLayout.contentClearance)
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
