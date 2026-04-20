import SwiftUI

struct InsightsSheetContent: View {
    @ObservedObject var authSession: LociqAuthSession
    let zipCode: String?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let zipBundle: ZipLookupResult?
    let metricsSource: MetricsSource?
    let hasActiveSelection: Bool
    let isLoadingSelection: Bool
    @ObservedObject var subscriptionManager: LociqSubscriptionManager
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
                            KeyMetricsGrid(metrics: metrics)
                            GeneratedInsightsSection(insights: [], isLoading: true)
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
                                PremiumAISection(
                                    authSession: authSession,
                                    subscriptionManager: subscriptionManager,
                                    areaTitle: areaTitle,
                                    areaSubtitle: areaSubtitle,
                                    demographics: demographics,
                                    zipBundle: zipBundle,
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

private struct PremiumAISection: View {
    @ObservedObject var authSession: LociqAuthSession
    @ObservedObject var subscriptionManager: LociqSubscriptionManager
    let areaTitle: String
    let areaSubtitle: String
    let demographics: Demographics
    let zipBundle: ZipLookupResult?
    let themeTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeTint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium AI brief")
                        .font(.headline)
                    Text(
                        subscriptionManager.hasActivePremium
                            ? "Generate a concise investor-style brief for this area from the current Census profile."
                            : "AI summaries are reserved for subscribers. Core map and Census features stay available to everyone."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            if let latestAIBrief = subscriptionManager.latestAIBrief, !latestAIBrief.isEmpty {
                Text(latestAIBrief)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let aiBriefError = subscriptionManager.aiBriefError, !aiBriefError.isEmpty {
                Text(aiBriefError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        await subscriptionManager.generateNeighborhoodBrief(
                            areaTitle: areaTitle,
                            areaSubtitle: areaSubtitle,
                            zcta: zipBundle?.zcta,
                            tractGeoid: zipBundle?.tract?.geoid,
                            demographics: demographicsPayload
                        )
                    }
                } label: {
                    Label(
                        subscriptionManager.isGeneratingBrief ? "Generating…" : "Generate AI Brief",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(subscriptionManager.isGeneratingBrief || !subscriptionManager.hasActivePremium)

                if subscriptionManager.hasActivePremium {
                    Button("Refresh Access") {
                        Task {
                            await subscriptionManager.refresh()
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(subscriptionManager.isBusy ? "Loading…" : "Unlock AI") {
                        Task {
                            if authSession.isSignedIn {
                                await subscriptionManager.purchasePremium()
                            } else {
                                await authSession.ensureSignedIn()
                                await subscriptionManager.purchasePremium()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(subscriptionManager.isBusy)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(themeTint.opacity(0.15), lineWidth: 1)
        )
    }

    private var demographicsPayload: [String: Any] {
        var payload: [String: Any] = [
            "name": demographics.name
        ]

        func insert(_ key: String, _ value: Any?) {
            if let value {
                payload[key] = value
            }
        }

        insert("averageHouseholdSize", demographics.averageHouseholdSize)
        insert("blackAlone", demographics.blackAlone)
        insert("hispanicOrLatino", demographics.hispanicOrLatino)
        insert("housingUnits", demographics.housingUnits)
        insert("medianAge", demographics.medianAge)
        insert("medianGrossRent", demographics.medianGrossRent)
        insert("medianHomeValue", demographics.medianHomeValue)
        insert("medianHouseholdIncome", demographics.medianHouseholdIncome)
        insert("ownerOccupiedPct", demographics.ownerOccupiedPct)
        insert("population", demographics.population)
        insert("povertyRatePct", demographics.povertyRatePct)
        insert("renterOccupiedPct", demographics.renterOccupiedPct)
        insert("whiteAlone", demographics.whiteAlone)
        insert("workersWfhPct", demographics.workersWfhPct)
        return payload
    }
}
