import SwiftUI

struct InsightsSheetPresentation {
    let zipCode: String?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let zipBundle: ZipLookupResult?
    let metricsSource: MetricsSource?
    let hasActiveSelection: Bool
    let isLoadingSelection: Bool
    let selectionFeedbackState: SelectionFeedbackState?
    let isRefreshingScale: Bool
    let comparisonProfile: ComparablePlaceProfile?
    let pendingComparisonTitle: String?
    let isLoadingComparison: Bool
    let comparisonErrorMessage: String?
    let isCurrentPlaceSaved: Bool
    let currentLibraryEntry: NeighborhoodLibraryEntry?
    let isCurrentComparisonSaved: Bool
}

struct InsightsSheetContent: View {
    let presentation: InsightsSheetPresentation
    let onRetrySelection: () -> Void
    let onStartCompare: () -> Void
    let onReplaceCompare: () -> Void
    let onClearCompare: () -> Void
    let onToggleSaved: () -> Void
    let onSavePlaceDetails: (String, String, Bool) -> Void
    let onSaveComparison: () -> Void
    @Binding var boundaryScale: BoundaryOverlayScale
    @Binding var sheetOffset: CGFloat

    @State private var hintVisible: Bool = true
    @State private var shareAsset: NeighborhoodShareCardAsset?
    @State private var comparisonShareAsset: ComparisonShareCardAsset?
    @State private var libraryEditorDraft: EditableNeighborhoodLibraryEntry?

    init(
        presentation: InsightsSheetPresentation,
        onRetrySelection: @escaping () -> Void,
        onStartCompare: @escaping () -> Void = {},
        onReplaceCompare: @escaping () -> Void = {},
        onClearCompare: @escaping () -> Void = {},
        onToggleSaved: @escaping () -> Void,
        onSavePlaceDetails: @escaping (String, String, Bool) -> Void,
        onSaveComparison: @escaping () -> Void,
        boundaryScale: Binding<BoundaryOverlayScale>,
        sheetOffset: Binding<CGFloat>
    ) {
        self.presentation = presentation
        self.onRetrySelection = onRetrySelection
        self.onStartCompare = onStartCompare
        self.onReplaceCompare = onReplaceCompare
        self.onClearCompare = onClearCompare
        self.onToggleSaved = onToggleSaved
        self.onSavePlaceDetails = onSavePlaceDetails
        self.onSaveComparison = onSaveComparison
        self._boundaryScale = boundaryScale
        self._sheetOffset = sheetOffset
    }

    private var zipCode: String? { presentation.zipCode }
    private var metrics: CensusMetrics? { presentation.metrics }
    private var demographics: Demographics? { presentation.demographics }
    private var zipBundle: ZipLookupResult? { presentation.zipBundle }
    private var metricsSource: MetricsSource? { presentation.metricsSource }
    private var hasActiveSelection: Bool { presentation.hasActiveSelection }
    private var isLoadingSelection: Bool { presentation.isLoadingSelection }
    private var selectionFeedbackState: SelectionFeedbackState? { presentation.selectionFeedbackState }
    private var isRefreshingScale: Bool { presentation.isRefreshingScale }
    private var comparisonProfile: ComparablePlaceProfile? { presentation.comparisonProfile }
    private var pendingComparisonTitle: String? { presentation.pendingComparisonTitle }
    private var isLoadingComparison: Bool { presentation.isLoadingComparison }
    private var comparisonErrorMessage: String? { presentation.comparisonErrorMessage }
    private var isCurrentPlaceSaved: Bool { presentation.isCurrentPlaceSaved }
    private var currentLibraryEntry: NeighborhoodLibraryEntry? { presentation.currentLibraryEntry }
    private var isCurrentComparisonSaved: Bool { presentation.isCurrentComparisonSaved }
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

    private var canShareSelection: Bool {
        hasActiveSelection &&
        !showsNoCoverageState &&
        !showsSampleFallbackState &&
        (metrics != nil || demographics != nil)
    }

    private var shareExportIdentity: String {
        let visibleInsightTitles = insights
            .filter { $0.category != .housing }
            .prefix(2)
            .map(\.title)
            .joined(separator: "|")
        let sourceText = metricsSource.map(InsightsFormatting.dataSourceText) ?? "none"
        let populationValue = String(metrics?.population ?? demographics?.population ?? -1)
        let incomeValue = String(metrics?.medianIncome ?? demographics?.medianHouseholdIncome ?? -1)
        let householdsValue = String(metrics?.households ?? -1)
        let ageValue = String(demographics?.medianAge ?? metrics?.medianAge ?? -1)

        return [
            canShareSelection ? "ready" : "disabled",
            areaTitle,
            areaSubtitle,
            boundaryScale.rawValue,
            sourceText,
            populationValue,
            incomeValue,
            householdsValue,
            ageValue,
            visibleInsightTitles
        ].joined(separator: "::")
    }

    private var comparisonShareExportIdentity: String {
        guard let primaryComparisonProfile, let comparisonProfile else { return "disabled" }

        return [
            boundaryScale.rawValue,
            primaryComparisonProfile.id,
            comparisonProfile.id,
            InsightsFormatting.number(primaryComparisonProfile.metrics.population),
            InsightsFormatting.number(comparisonProfile.metrics.population),
            InsightsFormatting.currency(primaryComparisonProfile.metrics.medianIncome),
            InsightsFormatting.currency(comparisonProfile.metrics.medianIncome)
        ].joined(separator: "::")
    }

    private var isFallbackToZIP: Bool {
        boundaryScale == .tract && metricsSource == .zcta
    }

    private var isCompareModeActive: Bool {
        comparisonProfile != nil || isLoadingComparison || comparisonErrorMessage != nil
    }

    private var primaryComparisonProfile: ComparablePlaceProfile? {
        guard
            hasActiveSelection,
            !showsNoCoverageState,
            !showsSampleFallbackState,
            let metrics,
            let metricsSource
        else {
            return nil
        }

        return ComparablePlaceProfile(
            id: zipBundle?.tract?.geoid ?? zipCode ?? areaTitle,
            title: areaTitle,
            subtitle: areaSubtitle,
            metrics: metrics,
            demographics: demographics,
            metricsSource: metricsSource
        )
    }

    private var showsNoCoverageState: Bool {
        selectionFeedbackState == .noCoverage
    }

    private var showsSampleFallbackState: Bool {
        selectionFeedbackState == .sampleFallback
    }

    var body: some View {
        content
            .task {
                guard hintVisible else { return }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    hintVisible = false
                }
            }
            .task(id: shareExportIdentity) {
                guard canShareSelection else {
                    shareAsset = nil
                    return
                }

                shareAsset = NeighborhoodShareCardExporter.makeAsset(
                    areaTitle: areaTitle,
                    areaSubtitle: areaSubtitle,
                    boundaryScale: boundaryScale,
                    metricsSource: metricsSource,
                    metrics: metrics,
                    demographics: demographics,
                    insights: insights
                )
            }
            .task(id: comparisonShareExportIdentity) {
                guard let primaryComparisonProfile, let comparisonProfile else {
                    comparisonShareAsset = nil
                    return
                }

                comparisonShareAsset = ComparisonShareCardExporter.makeAsset(
                    boundaryScale: boundaryScale,
                    primary: primaryComparisonProfile,
                    secondary: comparisonProfile
                )
            }
            .sheet(item: $libraryEditorDraft) { draft in
                NeighborhoodLibraryEditorSheet(
                    draft: draft,
                    onSave: { updatedDraft in
                        onSavePlaceDetails(
                            updatedDraft.customLabel,
                            updatedDraft.note,
                            updatedDraft.isPinned
                        )
                    }
                )
            }
            .animation(.easeInOut(duration: 0.3), value: refreshAnimationKey)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if isCollapsed {
                collapsedContent
            } else {
                expandedContent
            }
        }
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            CollapsedInsightsHeaderRow(
                areaTitle: areaTitle,
                areaSubtitle: areaSubtitle,
                zipLine: zipLine,
                boundaryScale: $boundaryScale,
                hintVisible: hintVisible,
                hasActiveSelection: hasActiveSelection
            )

            collapsedStatusContent
        }
    }

    @ViewBuilder
    private var collapsedStatusContent: some View {
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
        } else if isCompareModeActive {
            CollapsedComparisonPreviewCard(
                primaryTitle: areaTitle,
                secondaryTitle: comparisonProfile?.title ?? pendingComparisonTitle,
                isLoadingSecondary: isLoadingComparison,
                boundaryScale: boundaryScale
            )
        } else if hasActiveSelection || isLoadingSelection {
            CollapsedInsightsMetricsGrid(metrics: metrics)
        } else {
            CompactSheetPromptCard()
        }
    }

    private var expandedContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                expandedStatusContent
            }
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var expandedStatusContent: some View {
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
            expandedProfileContent
        }
    }

    @ViewBuilder
    private var expandedProfileContent: some View {
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
            isComparing: isCompareModeActive,
            isCurrentPlaceSaved: isCurrentPlaceSaved,
            onStartCompare: onStartCompare,
            onToggleSaved: onToggleSaved,
            onEditLibraryEntry: {
                libraryEditorDraft = EditableNeighborhoodLibraryEntry(
                    id: currentLibraryEntry?.id ?? zipBundle?.tract?.geoid ?? areaTitle,
                    defaultTitle: currentLibraryEntry?.title ?? areaTitle,
                    customLabel: currentLibraryEntry?.normalizedCustomLabel ?? "",
                    note: currentLibraryEntry?.normalizedNote ?? "",
                    isPinned: currentLibraryEntry?.isPinned ?? false
                )
            },
            shareAsset: shareAsset,
            boundaryScale: $boundaryScale
        )
        .id("header-\(refreshAnimationKey)")
        .transition(.opacity.combined(with: .move(edge: .top)))

        if isCompareModeActive, let primaryComparisonProfile {
            PlaceComparisonSection(
                primary: primaryComparisonProfile,
                secondary: comparisonProfile,
                pendingSecondaryTitle: pendingComparisonTitle,
                isLoadingSecondary: isLoadingComparison,
                comparisonErrorMessage: comparisonErrorMessage,
                boundaryScale: boundaryScale,
                onReplaceComparison: onReplaceCompare,
                onClearComparison: onClearCompare,
                isComparisonSaved: isCurrentComparisonSaved,
                onSaveComparison: onSaveComparison,
                shareAsset: comparisonShareAsset
            )
        } else {
            expandedMetricsContent
        }
    }

    @ViewBuilder
    private var expandedMetricsContent: some View {
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
