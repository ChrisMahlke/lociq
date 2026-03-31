import SwiftUI
import StoreKit

private struct MockSchool: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: String
    let grades: String
    let rating: Double

    var ratingText: String {
        String(format: "%.1f", rating)
    }
}

private struct SchoolGroup: Identifiable, Hashable {
    let title: String
    let schools: [MockSchool]

    var id: String { title }
}

struct CollapsedInsightsHeaderRow: View {
    let areaTitle: String
    let areaSubtitle: String
    let zipLine: String
    @Binding var boundaryScale: BoundaryOverlayScale
    let hintVisible: Bool
    let hasActiveSelection: Bool

    private var contextItems: [String] {
        if hasActiveSelection {
            return areaSubtitle
                .split(separator: "·")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        return ["Tap the map", "Expand for more"]
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hasActiveSelection ? areaTitle : AppStrings.Labels.noSelectionTitle)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.primary)
                Text(AppStrings.Labels.collapsedHint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.72))
                ContextPillRow(items: contextItems, tint: hasActiveSelection ? boundaryScale.themeColor : .blue)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                BoundaryScaleSwitch(scale: $boundaryScale)
                SwipeUpHint()
                    .opacity(hintVisible ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: hintVisible)
            }
        }
    }
}

struct CollapsedInsightsMetricsGrid: View {
    let metrics: CensusMetrics?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            CollapsedMetricChip(
                icon: IconNames.personFilled,
                label: AppStrings.Metrics.population,
                value: InsightsFormatting.number(metrics?.population),
                loading: metrics == nil
            )
            CollapsedMetricChip(
                icon: IconNames.money,
                label: AppStrings.Metrics.medianIncome,
                value: metrics?.medianIncome.map { InsightsFormatting.currency($0) },
                loading: metrics == nil
            )
            CollapsedMetricChip(
                icon: IconNames.clock,
                label: AppStrings.Metrics.medianAge,
                value: metrics?.medianAge.map { String(format: AppStrings.Symbols.oneDecimalFormat, $0) },
                loading: metrics == nil
            )
            CollapsedMetricChip(
                icon: IconNames.house,
                label: AppStrings.Metrics.households,
                value: InsightsFormatting.number(metrics?.households),
                loading: metrics == nil
            )
        }
    }
}

struct ExpandedInsightsHeaderRow: View {
    let areaTitle: String
    let areaSubtitle: String
    let zipCode: String?
    let metricsSource: MetricsSource?
    let isFallbackToZIP: Bool
    @Binding var boundaryScale: BoundaryOverlayScale

    private var contextItems: [String] {
        areaSubtitle.isEmpty ? (zipCode.map { ["ZIP \($0)"] } ?? []) : areaSubtitle
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(areaTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()
            }

            ContextPillRow(items: contextItems, tint: boundaryScale.themeColor)
            ScaleStatusBanner(boundaryScale: $boundaryScale, isFallbackToZIP: isFallbackToZIP)
        }
    }
}

struct HousingAffordabilitySection: View {
    let demographics: Demographics

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                OccupancySplitBar(
                    ownerText: InsightsFormatting.percent(demographics.ownerOccupiedPct, suffixCount: demographics.ownerOccupied),
                    renterText: InsightsFormatting.percent(demographics.renterOccupiedPct, suffixCount: demographics.renterOccupied),
                    ownerShare: InsightsFormatting.normalizedPercent(demographics.ownerOccupiedPct)
                )
            }
        }
    }
}

struct DemographicCompositionSection: View {
    let demographics: Demographics
    let totalPopulation: Int?
    let themeTint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                InsightSectionHeader(
                    title: AppStrings.Labels.demographicCompositionVisual,
                    subtitle: "Relative group sizes within the selected area",
                    icon: "person.3.sequence.fill",
                    tint: themeTint
                )

                CompositionRow(
                    label: AppStrings.Labels.white,
                    countText: InsightsFormatting.number(demographics.whiteAlone),
                    progress: InsightsFormatting.demographicShare(demographics.whiteAlone, totalPopulation: totalPopulation),
                    tint: themeTint
                )
                CompositionRow(
                    label: AppStrings.Labels.black,
                    countText: InsightsFormatting.number(demographics.blackAlone),
                    progress: InsightsFormatting.demographicShare(demographics.blackAlone, totalPopulation: totalPopulation),
                    tint: themeTint.opacity(0.84)
                )
                CompositionRow(
                    label: AppStrings.Labels.asian,
                    countText: InsightsFormatting.number(demographics.asianAlone),
                    progress: InsightsFormatting.demographicShare(demographics.asianAlone, totalPopulation: totalPopulation),
                    tint: themeTint.opacity(0.70)
                )
                CompositionRow(
                    label: AppStrings.Labels.hispanicLatino,
                    countText: InsightsFormatting.number(demographics.hispanicOrLatino),
                    progress: InsightsFormatting.demographicShare(demographics.hispanicOrLatino, totalPopulation: totalPopulation),
                    tint: themeTint.opacity(0.58)
                )
            }
        }
    }
}

struct SchoolsPreviewSection: View {
    let zipCode: String
    let themeTint: Color
    @EnvironmentObject private var schoolAccessController: SchoolAccessController

    private var groups: [SchoolGroup] {
        MockSchoolFactory.makeGroups(for: zipCode)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                InsightSectionHeader(
                    title: "Schools in ZIP \(zipCode)",
                    subtitle: "Mock preview with sample ratings for public and private schools",
                    icon: "graduationcap.fill",
                    tint: themeTint
                )

                if schoolAccessController.hasUnlockedSchoolData {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(themeTint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(themeTint.opacity(0.12), in: Capsule())

                            ForEach(group.schools) { school in
                                SchoolRow(school: school, tint: themeTint)
                            }
                        }
                    }
                } else {
                    SchoolsLockedTeaser(
                        groups: groups,
                        tint: themeTint
                    )
                }
            }
        }
    }
}

struct GeneratedInsightsSection: View {
    let insights: [Insight]
    let isLoading: Bool

    private var visibleInsights: [Insight] {
        insights.filter { $0.title != "Housing snapshot" }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                InsightSectionHeader(
                    title: AppStrings.Labels.insights,
                    subtitle: "Plain-English takeaways generated from the active area profile",
                    icon: "text.bubble.fill",
                    tint: .indigo
                )
                if isLoading {
                    InsightLoadingPanel()
                } else if visibleInsights.isEmpty {
                    Text(AppStrings.Labels.noGeneratedInsights)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.8)
                        .clipped()
                } else {
                    InsightRedesignPanel(insights: visibleInsights)
                }
            }
        }
    }
}

private struct SchoolRow: View {
    let school: MockSchool
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(school.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(school.kind) • \(school.grades)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(school.ratingText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()

                Text("Mock rating")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.9)
        )
    }
}

private struct SchoolsLockedTeaser: View {
    let groups: [SchoolGroup]
    let tint: Color
    @EnvironmentObject private var schoolAccessController: SchoolAccessController
    @State private var showingPaywall = false

    private var previewRows: [MockSchool] {
        groups.compactMap { $0.schools.first }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.12), in: Capsule())

            ForEach(previewRows) { school in
                SchoolRow(school: school, tint: tint)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("See the full grouped school list, ratings, and school mix for this ZIP.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Button("View school access") {
                    showingPaywall = true
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let purchaseMessage = schoolAccessController.purchaseMessage {
                    Text(purchaseMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 0.9)
            )
        }
        .sheet(isPresented: $showingPaywall) {
            SchoolsPaywallSheet(tint: tint)
                .environmentObject(schoolAccessController)
        }
    }
}

private struct SchoolsPaywallSheet: View {
    let tint: Color
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var schoolAccessController: SchoolAccessController

    private var unlockButtonTitle: String {
        if let product = schoolAccessController.product {
            return "Unlock for \(product.displayPrice)"
        }

        if schoolAccessController.isLoadingProducts {
            return "Loading..."
        }

        return "Unlock school data"
    }

    private let features = [
        "Full school list for the selected ZIP",
        "Elementary through high school coverage",
        "Public and private school mix",
        "School ratings and cleaner sorting"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Unlock School Data")
                            .font(.title2.weight(.bold))

                        Text("See the full school list for this ZIP with organized grade bands, ratings, and school mix.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(tint)
                                Text(feature)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            Task {
                                await schoolAccessController.purchaseSchoolsUnlock()
                                if schoolAccessController.hasUnlockedSchoolData {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if schoolAccessController.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(unlockButtonTitle)
                                        .font(.headline.weight(.semibold))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(schoolAccessController.isLoadingProducts || schoolAccessController.isPurchasing)

                        Button("Restore Purchases") {
                            Task {
                                await schoolAccessController.restorePurchases()
                                if schoolAccessController.hasUnlockedSchoolData {
                                    dismiss()
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)

                        if let purchaseMessage = schoolAccessController.purchaseMessage {
                            Text(purchaseMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("School Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum MockSchoolFactory {
    private static let elementaryNames = [
        "Oak Grove Elementary",
        "Maple Ridge Elementary",
        "Sunrise Elementary",
        "Cedar Park Elementary"
    ]

    private static let middleNames = [
        "Valley View Middle",
        "Ridgecrest Middle",
        "Heritage Middle",
        "Brookside Middle"
    ]

    private static let highNames = [
        "Central High",
        "Westview High",
        "Liberty High",
        "North Ridge High"
    ]

    private static let privateNames = [
        "Starlight Academy",
        "Covenant Prep",
        "Summit Christian School",
        "Horizon College Prep"
    ]

    static func makeGroups(for zipCode: String) -> [SchoolGroup] {
        let seed = zipCode.compactMap(\.wholeNumberValue).reduce(0, +)

        let elementary = [
            MockSchool(
                id: "\(zipCode)-elementary-public-1",
                name: pick(from: elementaryNames, seed: seed),
                kind: "Public elementary school",
                grades: "K-5",
                rating: rating(seed: seed, offset: 0)
            ),
            MockSchool(
                id: "\(zipCode)-elementary-private-1",
                name: pick(from: privateNames, seed: seed + 1),
                kind: "Private elementary school",
                grades: "K-6",
                rating: rating(seed: seed, offset: 1)
            )
        ]
        .sorted { $0.rating > $1.rating }

        let middle = [
            MockSchool(
                id: "\(zipCode)-middle-public-1",
                name: pick(from: middleNames, seed: seed + 2),
                kind: "Public middle school",
                grades: "6-8",
                rating: rating(seed: seed, offset: 2)
            ),
            MockSchool(
                id: "\(zipCode)-middle-private-1",
                name: "\(pick(from: privateNames, seed: seed + 3)) Middle Division",
                kind: "Private middle school",
                grades: "6-8",
                rating: rating(seed: seed, offset: 3)
            )
        ]
        .sorted { $0.rating > $1.rating }

        let high = [
            MockSchool(
                id: "\(zipCode)-high-public-1",
                name: pick(from: highNames, seed: seed + 4),
                kind: "Public high school",
                grades: "9-12",
                rating: rating(seed: seed, offset: 4)
            ),
            MockSchool(
                id: "\(zipCode)-high-private-1",
                name: "\(pick(from: privateNames, seed: seed + 5)) Upper School",
                kind: "Private high school",
                grades: "9-12",
                rating: rating(seed: seed, offset: 5)
            )
        ]
        .sorted { $0.rating > $1.rating }

        return [
            SchoolGroup(title: "Elementary", schools: elementary),
            SchoolGroup(title: "Middle School", schools: middle),
            SchoolGroup(title: "High School", schools: high)
        ]
    }

    private static func pick(from values: [String], seed: Int) -> String {
        guard !values.isEmpty else { return "Local School" }
        return values[abs(seed) % values.count]
    }

    private static func rating(seed: Int, offset: Int) -> Double {
        let raw = 68 + ((seed * 7 + offset * 9) % 28)
        return Double(raw) / 10.0
    }
}
