import SwiftUI

struct MoreScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                DataHeroCard()

                DataSectionCard(
                    title: "Core profile metrics",
                    subtitle: "Displayed in the top metric grid",
                    icon: "person.2.square.stack.fill",
                    tint: .blue,
                    rows: [
                        DataDefinitionRow(label: "Population", source: "ACS 5-Year (U.S. Census)", note: "Total residents estimate"),
                        DataDefinitionRow(label: "Median income", source: "ACS 5-Year (U.S. Census)", note: "Median household income"),
                        DataDefinitionRow(label: "Median age", source: "ACS 5-Year (U.S. Census)", note: "Population median age"),
                        DataDefinitionRow(label: "Households", source: "ACS 5-Year (U.S. Census)", note: "Estimated occupied units")
                    ]
                )

                DataSectionCard(
                    title: "Neighborhood context",
                    subtitle: "Shown in visual cards",
                    icon: "map.circle.fill",
                    tint: .orange,
                    rows: [
                        DataDefinitionRow(label: "Home value / rent", source: "ACS 5-Year", note: "Median home value and median gross rent"),
                        DataDefinitionRow(label: "Remote work / poverty", source: "ACS 5-Year", note: "Work-from-home share and poverty rate"),
                        DataDefinitionRow(label: "Demographic composition", source: "ACS 5-Year", note: "Counts and relative share by group")
                    ]
                )

                DataSectionCard(
                    title: "Boundaries & geography",
                    subtitle: "Overlayed directly on the map",
                    icon: "square.stack.3d.up.fill",
                    tint: .mint,
                    rows: [
                        DataDefinitionRow(label: "ZIP boundary", source: "TIGER/Line + TIGERweb", note: "ZCTA geometry used for ZIP overlays"),
                        DataDefinitionRow(label: "Census tract boundary", source: "TIGER/Line + TIGERweb", note: "Tract geometry for finer context"),
                        DataDefinitionRow(label: "Coordinate lookup", source: "FCC Census Block API", note: "Lat/long resolves to Census geographies")
                    ]
                )

                DataSectionCard(
                    title: "Map controls",
                    subtitle: "Quick camera shortcuts on the map",
                    icon: "location.viewfinder",
                    tint: .teal,
                    rows: [
                        DataDefinitionRow(label: "My Area icon", source: "location.fill", note: "Centers the map on your current location, or your latest tapped area if location is unavailable"),
                        DataDefinitionRow(label: "Reset icon", source: "scope", note: "Returns to the default city overview so you can quickly start a new exploration")
                    ]
                )

                SourceBadgeGrid()

                DataQualityFootnoteCard()

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStrings.Labels.howToUseTitle)
                            .font(.headline)
                        StepLine(text: AppStrings.Labels.mapInstructionOne)
                        StepLine(text: AppStrings.Labels.mapInstructionTwo)
                        StepLine(text: AppStrings.Labels.mapInstructionThree)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct DataHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.18), in: Circle())
                Text("Data transparency")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Text("UrbanPulse combines official Census geography and ACS estimates into a quick visual neighborhood brief.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 8) {
                PillTag(text: "U.S. Census", tint: .white.opacity(0.2), foreground: .white)
                PillTag(text: "ACS 5-Year", tint: .white.opacity(0.2), foreground: .white)
                PillTag(text: "TIGERweb", tint: .white.opacity(0.2), foreground: .white)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.indigo, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: .blue.opacity(0.18), radius: 10, y: 4)
    }
}

private struct DataSectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let rows: [DataDefinitionRow]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(tint.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        DataDefinitionRowView(row: row)
                    }
                }
            }
        }
    }
}

private struct DataDefinitionRowView: View {
    let row: DataDefinitionRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.label)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(row.source)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Text(row.note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SourceBadgeGrid: View {
    private let sources: [(title: String, icon: String, tint: Color)] = [
        ("U.S. Census Bureau", "building.columns.fill", .indigo),
        ("ACS 5-Year Estimates", "chart.xyaxis.line", .blue),
        ("TIGERweb Geometry", "square.on.square.squareshape.controlhandles", .orange),
        ("FCC Block Lookup", "antenna.radiowaves.left.and.right", .mint)
    ]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Primary sources")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(sources, id: \.title) { source in
                        HStack(spacing: 6) {
                            Image(systemName: source.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(source.tint)
                            Text(source.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(source.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct DataQualityFootnoteCard: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .frame(width: 24, height: 24)
                        .background(Color.green.opacity(0.15), in: Circle())
                    Text("Data quality notes")
                        .font(.headline)
                }

                InfoLine(icon: "calendar", title: "Latest ACS dataset", detail: "2022 ACS 5-Year release")
                InfoLine(icon: "waveform.path.ecg", title: "Values are estimates", detail: "Census values include statistical uncertainty")
                InfoLine(icon: "location", title: "Boundary geometry", detail: "ZIP and tract polygons are generalized for map display")
                InfoLine(icon: "clock", title: "Refresh behavior", detail: "Profiles update each time you tap a new location")
            }
        }
    }
}

private struct InfoLine: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StepLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.25))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PillTag: View {
    let text: String
    let tint: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
            .foregroundStyle(foreground)
    }
}

private struct DataDefinitionRow: Identifiable {
    let id = UUID()
    let label: String
    let source: String
    let note: String
}
