import SwiftUI

struct MoreScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var libraryStore: NeighborhoodLibraryStore
    let onSelectPlace: (NeighborhoodLibraryEntry) -> Void

    private var backgroundWashColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.13, blue: 0.20),
                Color(red: 0.07, green: 0.19, blue: 0.18),
                Color(.systemGroupedBackground)
            ]
        }

        return [
            Color(red: 0.90, green: 0.96, blue: 0.98),
            Color(red: 0.95, green: 0.97, blue: 0.95),
            Color(.systemGroupedBackground)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MoreHeroCard()
                NeighborhoodLibraryCard(
                    title: AppStrings.More.savedPlaces,
                    subtitle: AppStrings.More.savedPlacesSubtitle,
                    icon: "bookmark.fill",
                    tint: .blue,
                    entries: libraryStore.savedPlaces,
                    emptyState: AppStrings.More.noSavedPlacesYet,
                    onSelectPlace: onSelectPlace
                )
                NeighborhoodLibraryCard(
                    title: AppStrings.More.recentLookups,
                    subtitle: AppStrings.More.recentLookupsSubtitle,
                    icon: "clock.arrow.circlepath",
                    tint: .teal,
                    entries: libraryStore.recentLookups,
                    emptyState: AppStrings.More.noRecentLookupsYet,
                    onSelectPlace: onSelectPlace
                )
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
                    colors: backgroundWashColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                .blur(radius: 10)
            }
        )
    }
}

private struct NeighborhoodLibraryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let entries: [NeighborhoodLibraryEntry]
    let emptyState: String
    let onSelectPlace: (NeighborhoodLibraryEntry) -> Void

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    tint: tint
                )

                if entries.isEmpty {
                    Text(emptyState)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            Button {
                                onSelectPlace(entry)
                            } label: {
                                NeighborhoodLibraryRow(entry: entry, tint: tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct NeighborhoodLibraryRow: View {
    let entry: NeighborhoodLibraryEntry
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.isSaved ? "bookmark.fill" : "clock.arrow.circlepath")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(entry.preferredScale.displayTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint.opacity(0.8))
                .padding(.top, 3)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    Text(AppStrings.More.heroTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("more.hero.title")
                    Text(AppStrings.More.heroSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(AppStrings.More.heroBody)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.93))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                HeroSignalPill(title: AppStrings.More.broadScan, subtitle: AppStrings.More.zipTitle)
                HeroSignalPill(title: AppStrings.More.localDetail, subtitle: AppStrings.More.tractTitle)
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
        (AppStrings.More.tapAnySpot, AppStrings.More.tapAnySpotDetail, .blue),
        (AppStrings.More.switchScale, AppStrings.More.switchScaleDetail, .teal),
        (AppStrings.Labels.readTheProfile, AppStrings.More.readTheProfileDetail, .indigo)
    ]

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: AppStrings.More.startHere,
                    subtitle: AppStrings.More.startHereSubtitle,
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: AppStrings.More.zipVsTract,
                    subtitle: AppStrings.More.zipVsTractSubtitle,
                    icon: "square.stack.3d.up.fill",
                    tint: .mint
                )

                if horizontalSizeClass == .compact {
                    VStack(spacing: 10) {
                        scaleCards
                    }
                } else {
                    HStack(spacing: 10) {
                        scaleCards
                    }
                }

                CalloutStrip(
                    title: AppStrings.More.tip,
                    detail: AppStrings.More.tipDetail,
                    tint: .teal
                )
            }
        }
    }

    @ViewBuilder
    private var scaleCards: some View {
        ScaleSummaryCard(
            title: AppStrings.More.zipTitle,
            tint: .blue,
            icon: "square.fill",
            detail: AppStrings.More.zipDetail,
            emphasis: AppStrings.More.broaderView
        )

        ScaleSummaryCard(
            title: AppStrings.More.tractTitle,
            tint: .teal,
            icon: "square.fill",
            detail: AppStrings.More.tractDetail,
            emphasis: AppStrings.More.closerView
        )
    }
}

private struct WhatYouSeeCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let items: [(label: String, meaning: String, tint: Color)] = [
        (AppStrings.Metrics.population, AppStrings.More.populationMeaning, .blue),
        (AppStrings.Metrics.medianIncome, AppStrings.More.medianIncomeMeaning, .green),
        (AppStrings.Metrics.medianAge, AppStrings.More.medianAgeMeaning, .indigo),
        (AppStrings.Metrics.households, AppStrings.More.householdsMeaning, .orange),
        ("\(AppStrings.Labels.homeValue) / \(AppStrings.Labels.grossRent)", AppStrings.More.homeValueRentMeaning, .red),
        (AppStrings.Labels.occupancyMix, AppStrings.More.occupancyMixMeaning, .orange),
        ("\(AppStrings.Labels.remoteWork) / \(AppStrings.Labels.poverty)", AppStrings.More.remoteWorkPovertyMeaning, .mint),
        (AppStrings.Labels.demographicCompositionVisual, AppStrings.More.demographicCompositionMeaning, .purple)
    ]

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: AppStrings.More.whatYoureSeeing,
                    subtitle: AppStrings.More.whatYoureSeeingSubtitle,
                    icon: "chart.bar.xaxis",
                    tint: .orange
                )

                LazyVGrid(columns: columns, spacing: 8) {
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

    private var columns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(), spacing: 8)]
        }

        return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }
}

private struct MapControlsCard: View {
    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    title: AppStrings.More.mapControls,
                    subtitle: AppStrings.More.mapControlsSubtitle,
                    icon: "location.viewfinder",
                    tint: .teal
                )

                VStack(spacing: 8) {
                    ControlExplanationRow(
                        icon: "location.fill",
                        title: AppStrings.More.myArea,
                        detail: AppStrings.More.myAreaDetail,
                        tint: .blue
                    )

                    ControlExplanationRow(
                        icon: "scope",
                        title: AppStrings.More.resetMap,
                        detail: AppStrings.More.resetMapDetail,
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
                    title: AppStrings.More.privacyTrust,
                    subtitle: AppStrings.More.privacyTrustSubtitle,
                    icon: "lock.shield.fill",
                    tint: .green
                )

                InfoLine(
                    icon: "location.circle",
                    title: AppStrings.More.locationOptional,
                    detail: AppStrings.More.locationOptionalDetail
                )
                InfoLine(
                    icon: "person.crop.circle.badge.checkmark",
                    title: AppStrings.More.noAccountRequired,
                    detail: AppStrings.More.noAccountRequiredDetail
                )
                InfoLine(
                    icon: "building.columns",
                    title: AppStrings.More.officialPublicData,
                    detail: AppStrings.More.officialPublicDataDetail
                )
                InfoLine(
                    icon: "waveform.path.ecg",
                    title: AppStrings.More.theseAreEstimates,
                    detail: AppStrings.More.theseAreEstimatesDetail
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tint)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.16), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.26), lineWidth: 0.9)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SourceBadgeGrid: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let sources: [(title: String, icon: String, tint: Color)] = [
        (AppStrings.More.usCensusBureau, "building.columns.fill", .indigo),
        (AppStrings.More.acs5YearEstimates, "chart.xyaxis.line", .blue),
        (AppStrings.More.tigerwebGeometry, "square.on.square.squareshape.controlhandles", .teal),
        (AppStrings.More.fccBlockLookup, "antenna.radiowaves.left.and.right", .mint)
    ]

    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(
                    title: AppStrings.More.primarySources,
                    subtitle: AppStrings.More.primarySourcesSubtitle,
                    icon: "doc.text.magnifyingglass",
                    tint: .indigo
                )

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(sources, id: \.title) { source in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: source.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(source.tint)
                            Text(source.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
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

    private var columns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(), spacing: 8)]
        }

        return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }
}

private struct DataQualityFootnoteCard: View {
    var body: some View {
        SectionPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(
                    title: AppStrings.More.dataQualityNotes,
                    subtitle: AppStrings.More.dataQualityNotesSubtitle,
                    icon: "checkmark.seal.fill",
                    tint: .green
                )

                InfoLine(icon: "calendar", title: AppStrings.Labels.latestACSDataset, detail: AppStrings.Release.latestACS5YearDataset)
                InfoLine(icon: "waveform.path.ecg", title: AppStrings.Labels.valuesAreEstimatesShort, detail: AppStrings.Labels.censusValuesIncludeStatisticalUncertainty)
                InfoLine(icon: "location", title: AppStrings.Labels.boundaryGeometry, detail: AppStrings.Labels.zipAndTractPolygonsGeneralized)
                InfoLine(icon: "clock", title: AppStrings.Labels.refreshBehavior, detail: AppStrings.Labels.profilesUpdateEachTime)
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
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
