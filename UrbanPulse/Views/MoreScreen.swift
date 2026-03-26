import SwiftUI

struct MoreScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MoreHeroCard()
                QuickStartCard()
                ScaleComparisonCard()
                WhatYouSeeCard()
                MapControlsCard()
                PrivacyAndTrustCard()
                SourceBadgeGrid()
                DataQualityFootnoteCard()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.96, blue: 0.98),
                        Color(red: 0.95, green: 0.97, blue: 0.95),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                .blur(radius: 10)
            }
        )
    }
}

private struct MoreHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("How UrbanPulse works")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("A quick guide to reading the map and profile cards.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            Text("Tap a place, compare ZIP and tract views, and use the sheet to understand the area without digging through raw Census tables.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.93))

            HStack(spacing: 10) {
                HeroSignalPill(title: "Broad scan", subtitle: "ZIP")
                HeroSignalPill(title: "Local detail", subtitle: "Tract")
            }
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
        .shadow(color: Color.blue.opacity(0.14), radius: 12, y: 6)
    }
}

private struct QuickStartCard: View {
    private let steps: [(title: String, detail: String, tint: Color)] = [
        ("Tap any spot", "Select a location and load a neighborhood profile for that area.", .blue),
        ("Switch scale", "Use ZIP for a broader read and tract for more local variation.", .teal),
        ("Read the profile", "Swipe up to compare population, income, age, housing, and context.", .indigo)
    ]

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: "Start here",
                    subtitle: "The fastest way to get useful signal from the app",
                    icon: "sparkles.rectangle.stack.fill",
                    tint: .indigo
                )

                VStack(spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        QuickStartRow(
                            index: index + 1,
                            title: step.title,
                            detail: step.detail,
                            tint: step.tint
                        )
                    }
                }
            }
        }
    }
}

private struct ScaleComparisonCard: View {
    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: "ZIP vs Tract",
                    subtitle: "Use each scale for a different kind of question",
                    icon: "square.stack.3d.up.fill",
                    tint: .mint
                )

                HStack(spacing: 10) {
                    ScaleSummaryCard(
                        title: "ZIP",
                        tint: .blue,
                        icon: "square.fill",
                        detail: "Best for a broader neighborhood read and faster comparison across larger areas.",
                        emphasis: "Broader view"
                    )

                    ScaleSummaryCard(
                        title: "Tract",
                        tint: .teal,
                        icon: "square.fill",
                        detail: "Best for finer local context when nearby blocks may differ within the same ZIP.",
                        emphasis: "Closer view"
                    )
                }

                CalloutStrip(
                    title: "Tip",
                    detail: "If two nearby places look similar in ZIP view, switch to tract to check for more local variation.",
                    tint: .teal
                )
            }
        }
    }
}

private struct WhatYouSeeCard: View {
    private let items: [(label: String, meaning: String, tint: Color)] = [
        ("Population", "How many people live in the selected area.", .blue),
        ("Median income", "A quick proxy for household earning power in the area.", .green),
        ("Median age", "Whether the area skews younger, older, or more mixed.", .indigo),
        ("Households", "How many occupied homes are represented in this profile.", .orange),
        ("Home value / rent", "A fast read on local housing cost pressure.", .red),
        ("Occupancy mix", "Owner-occupied versus renter-occupied homes.", .orange),
        ("Remote work / poverty", "Two signals that can help describe work patterns and economic strain.", .mint),
        ("Demographic composition", "Relative group counts shown as simple visual comparisons.", .purple)
    ]

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: "What you’re seeing",
                    subtitle: "How to interpret the profile without reading every number in depth",
                    icon: "chart.bar.xaxis",
                    tint: .orange
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(items, id: \.label) { item in
                        InsightMeaningRow(
                            label: item.label,
                            detail: item.meaning,
                            tint: item.tint
                        )
                    }
                }
            }
        }
    }
}

private struct MapControlsCard: View {
    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: "Map controls",
                    subtitle: "Quick camera actions while exploring",
                    icon: "location.viewfinder",
                    tint: .teal
                )

                VStack(spacing: 8) {
                    ControlExplanationRow(
                        icon: "location.fill",
                        title: "My Area",
                        detail: "Centers the map on your current location, or your latest selected area if location is unavailable.",
                        tint: .blue
                    )

                    ControlExplanationRow(
                        icon: "scope",
                        title: "Reset Map",
                        detail: "Returns to the default city overview so you can quickly start a new comparison.",
                        tint: .teal
                    )
                }
            }
        }
    }
}

private struct PrivacyAndTrustCard: View {
    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: "Privacy and data trust",
                    subtitle: "What the app uses and what it does not",
                    icon: "lock.shield.fill",
                    tint: .green
                )

                InfoLine(
                    icon: "location.circle",
                    title: "Location is optional",
                    detail: "UrbanPulse uses location to center the map and help you explore nearby areas more quickly."
                )
                InfoLine(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "No account required",
                    detail: "You can use the app without signing in or creating a personal profile."
                )
                InfoLine(
                    icon: "building.columns",
                    title: "Official public data",
                    detail: "Profiles are built from U.S. Census ACS estimates and public geography services."
                )
                InfoLine(
                    icon: "waveform.path.ecg",
                    title: "These are estimates",
                    detail: "Census values are statistical estimates and should be treated as directional context, not exact counts."
                )
            }
        }
    }
}

private struct SectionHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct QuickStartRow: View {
    let index: Int
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint.opacity(0.8))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.10), Color.primary.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

private struct ScaleSummaryCard: View {
    let title: String
    let tint: Color
    let icon: String
    let detail: String
    let emphasis: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline.weight(.semibold))
            }

            Text(emphasis.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.12), tint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.9)
        )
    }
}

private struct CalloutStrip: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.12), tint.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

private struct InsightMeaningRow: View {
    let label: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 0.8)
        )
    }
}

private struct ControlExplanationRow: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SourceBadgeGrid: View {
    private let sources: [(title: String, icon: String, tint: Color)] = [
        ("U.S. Census Bureau", "building.columns.fill", .indigo),
        ("ACS 5-Year Estimates", "chart.xyaxis.line", .blue),
        ("TIGERweb Geometry", "square.on.square.squareshape.controlhandles", .teal),
        ("FCC Block Lookup", "antenna.radiowaves.left.and.right", .mint)
    ]

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(
                    title: "Primary sources",
                    subtitle: "The public datasets behind UrbanPulse",
                    icon: "doc.text.magnifyingglass",
                    tint: .indigo
                )

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
        SectionPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(
                    title: "Data quality notes",
                    subtitle: "Useful caveats when comparing places",
                    icon: "checkmark.seal.fill",
                    tint: .green
                )

                InfoLine(icon: "calendar", title: "Latest ACS dataset", detail: "2022 ACS 5-Year release")
                InfoLine(icon: "waveform.path.ecg", title: "Values are estimates", detail: "Census values include statistical uncertainty")
                InfoLine(icon: "location", title: "Boundary geometry", detail: "ZIP and tract polygons are generalized for map display")
                InfoLine(icon: "clock", title: "Refresh behavior", detail: "Profiles update each time you tap a new location")
            }
        }
    }
}

private struct SectionPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Card {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }
}

private struct HeroSignalPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.74))
            Text(subtitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
