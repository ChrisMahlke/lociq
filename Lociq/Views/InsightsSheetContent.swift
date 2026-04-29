import SwiftUI

struct InsightsSheetContent: View {
    let zipCode: String?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let zipBundle: ZipLookupResult?
    let metricsSource: MetricsSource?
    let hasActiveSelection: Bool
    let isLoadingSelection: Bool
    let selectionFeedbackState: SelectionFeedbackState?
    let isRefreshingScale: Bool
    let onRetrySelection: () -> Void
    let comparisonProfile: ComparablePlaceProfile?
    let pendingComparisonTitle: String?
    let isLoadingComparison: Bool
    let comparisonErrorMessage: String?
    let onStartCompare: () -> Void
    let onReplaceCompare: () -> Void
    let onClearCompare: () -> Void
    let isCurrentPlaceSaved: Bool
    let currentLibraryEntry: NeighborhoodLibraryEntry?
    let onToggleSaved: () -> Void
    let onSavePlaceDetails: (String, String, Bool) -> Void
    let isCurrentComparisonSaved: Bool
    let onSaveComparison: () -> Void
    @Binding var boundaryScale: BoundaryOverlayScale
    @Binding var sheetOffset: CGFloat

    @State private var hintVisible: Bool = true
    @State private var shareAsset: NeighborhoodShareCardAsset?
    @State private var comparisonShareAsset: ComparisonShareCardAsset?
    @State private var libraryEditorDraft: EditableNeighborhoodLibraryEntry?

    init(
        zipCode: String?,
        metrics: CensusMetrics?,
        demographics: Demographics?,
        zipBundle: ZipLookupResult?,
        metricsSource: MetricsSource?,
        hasActiveSelection: Bool,
        isLoadingSelection: Bool,
        selectionFeedbackState: SelectionFeedbackState?,
        isRefreshingScale: Bool,
        onRetrySelection: @escaping () -> Void,
        comparisonProfile: ComparablePlaceProfile? = nil,
        pendingComparisonTitle: String? = nil,
        isLoadingComparison: Bool = false,
        comparisonErrorMessage: String? = nil,
        onStartCompare: @escaping () -> Void = {},
        onReplaceCompare: @escaping () -> Void = {},
        onClearCompare: @escaping () -> Void = {},
        isCurrentPlaceSaved: Bool,
        onToggleSaved: @escaping () -> Void,
        currentLibraryEntry: NeighborhoodLibraryEntry?,
        onSavePlaceDetails: @escaping (String, String, Bool) -> Void,
        isCurrentComparisonSaved: Bool,
        onSaveComparison: @escaping () -> Void,
        boundaryScale: Binding<BoundaryOverlayScale>,
        sheetOffset: Binding<CGFloat>
    ) {
        self.zipCode = zipCode
        self.metrics = metrics
        self.demographics = demographics
        self.zipBundle = zipBundle
        self.metricsSource = metricsSource
        self.hasActiveSelection = hasActiveSelection
        self.isLoadingSelection = isLoadingSelection
        self.selectionFeedbackState = selectionFeedbackState
        self.isRefreshingScale = isRefreshingScale
        self.onRetrySelection = onRetrySelection
        self.comparisonProfile = comparisonProfile
        self.pendingComparisonTitle = pendingComparisonTitle
        self.isLoadingComparison = isLoadingComparison
        self.comparisonErrorMessage = comparisonErrorMessage
        self.onStartCompare = onStartCompare
        self.onReplaceCompare = onReplaceCompare
        self.onClearCompare = onClearCompare
        self.isCurrentPlaceSaved = isCurrentPlaceSaved
        self.onToggleSaved = onToggleSaved
        self.currentLibraryEntry = currentLibraryEntry
        self.onSavePlaceDetails = onSavePlaceDetails
        self.isCurrentComparisonSaved = isCurrentComparisonSaved
        self.onSaveComparison = onSaveComparison
        self._boundaryScale = boundaryScale
        self._sheetOffset = sheetOffset
    }

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
}
