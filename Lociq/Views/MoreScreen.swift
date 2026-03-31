import SwiftUI

struct MoreScreen: View {
    #if DEBUG
    @EnvironmentObject private var schoolAccessController: SchoolAccessController
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MoreHeroCard()
                QuickTipsCard()
                NeighborhoodCard()
                DataSourcesCard()
                TrustCard()
                #if DEBUG
                SchoolAccessDebugCard()
                #endif
            }
            .padding()
            .padding(.bottom, BottomRibbonLayout.contentClearance)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct MoreHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How to use Lociq", systemImage: "map.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text("Tap the map to view a quick local profile.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.28, blue: 0.54),
                    Color(red: 0.04, green: 0.46, blue: 0.57)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct QuickTipsCard: View {
    private let tips: [(icon: String, title: String, detail: String)] = [
        ("hand.tap.fill", "Tap", "Select an area."),
        ("arrow.left.and.right", "Toggle", "Switch between ZIP Code and Neighborhood."),
        ("rectangle.compress.vertical", "Swipe up", "See more details.")
    ]

    var body: some View {
        MoreSectionCard(title: "Quick Tips") {
            VStack(spacing: 10) {
                ForEach(tips, id: \.title) { tip in
                    HStack(spacing: 10) {
                        Image(systemName: tip.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                            .frame(width: 28, height: 28)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(tip.title)
                                .font(.subheadline.weight(.semibold))
                            Text(tip.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

private struct TrustCard: View {
    var body: some View {
        MoreSectionCard(title: "About the data") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Uses public data sources and map boundaries.")
                    .font(.subheadline)
                Text("Numbers are estimates, not exact counts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NeighborhoodCard: View {
    var body: some View {
        MoreSectionCard(title: "What Neighborhood Means") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Neighborhood is the smaller local area around the place you tapped.")
                    .font(.subheadline)

                Text("It gives a closer view than ZIP Code, which usually covers a larger area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DataSourcesCard: View {
    private let sources = [
        "U.S. Census data for population, income, age, and households.",
        "Public map boundary data for ZIP Codes and neighborhood areas."
    ]

    var body: some View {
        MoreSectionCard(title: "Where Data Comes From") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(sources, id: \.self) { source in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(source)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}

#if DEBUG
private struct SchoolAccessDebugCard: View {
    @EnvironmentObject private var schoolAccessController: SchoolAccessController

    var body: some View {
        MoreSectionCard(title: "Debug School Access") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Use this to test paid and unpaid school states without completing a purchase.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("School Access Override", selection: Binding(
                    get: { schoolAccessController.debugOverride },
                    set: { schoolAccessController.setDebugOverride($0) }
                )) {
                    ForEach(SchoolAccessController.DebugOverride.allCases) { override in
                        Text(override.title).tag(override)
                    }
                }
                .pickerStyle(.segmented)

                Text(schoolAccessController.hasUnlockedSchoolData ? "Current state: Unlocked" : "Current state: Locked")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}
#endif

private struct MoreSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    MoreScreen()
}
