import Combine
import CoreLocation
import Foundation

struct ComparablePlaceProfile: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let metrics: CensusMetrics
    let demographics: Demographics?
    let metricsSource: MetricsSource
}

@MainActor
final class CompareModeModel: ObservableObject {
    @Published private(set) var secondaryProfile: ComparablePlaceProfile?
    @Published private(set) var pendingComparisonTitle: String?
    @Published private(set) var isLoadingComparison: Bool = false
    @Published private(set) var comparisonErrorMessage: String?

    private let service: any CensusNeighborhoodServing
    private var activeComparisonTask: Task<Void, Never>?
    private var activeRequestID = UUID()
    private var selectedTarget: ComparisonTarget?

    init(service: any CensusNeighborhoodServing) {
        self.service = service
    }

    var hasComparisonState: Bool {
        secondaryProfile != nil || isLoadingComparison || comparisonErrorMessage != nil
    }

    func clear() {
        activeComparisonTask?.cancel()
        activeRequestID = UUID()
        selectedTarget = nil
        secondaryProfile = nil
        pendingComparisonTitle = nil
        isLoadingComparison = false
        comparisonErrorMessage = nil
    }

    func beginComparison(with result: PlaceSearchResult, scale: BoundaryOverlayScale) {
        let target = ComparisonTarget(
            coordinate: result.coordinate,
            fallbackTitle: result.title,
            fallbackSubtitle: result.subtitle,
            scale: scale
        )
        selectedTarget = target
        loadComparison(for: target, scale: scale, resetsVisibleProfile: true)
    }

    func makeSavedComparisonSnapshot(
        primary: NeighborhoodLookupSnapshot,
        scale: BoundaryOverlayScale
    ) -> SavedComparisonSnapshot? {
        guard let secondaryProfile, let selectedTarget else { return nil }

        let secondarySnapshot = NeighborhoodLookupSnapshot(
            id: secondaryProfile.id,
            title: secondaryProfile.title,
            subtitle: secondaryProfile.subtitle,
            zipCode: nil,
            latitude: selectedTarget.coordinate.latitude,
            longitude: selectedTarget.coordinate.longitude,
            preferredScale: scale
        )

        let title = "\(primary.title) \(AppStrings.Labels.compareVersus) \(secondaryProfile.title)"

        return SavedComparisonSnapshot(
            id: Self.comparisonID(primaryID: primary.id, secondaryID: secondaryProfile.id, scale: scale),
            title: title,
            summary: "\(scale.displayTitle) · \(primary.subtitle) · \(secondaryProfile.subtitle)",
            boundaryScale: scale,
            primary: primary,
            secondary: secondarySnapshot
        )
    }

    func refreshComparison(for scale: BoundaryOverlayScale) {
        guard var selectedTarget else { return }
        selectedTarget = ComparisonTarget(
            coordinate: selectedTarget.coordinate,
            fallbackTitle: selectedTarget.fallbackTitle,
            fallbackSubtitle: selectedTarget.fallbackSubtitle,
            scale: scale
        )
        self.selectedTarget = selectedTarget
        loadComparison(for: selectedTarget, scale: scale, resetsVisibleProfile: false)
    }

    private func loadComparison(
        for target: ComparisonTarget,
        scale: BoundaryOverlayScale,
        resetsVisibleProfile: Bool
    ) {
        activeComparisonTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        pendingComparisonTitle = target.fallbackTitle
        isLoadingComparison = true
        comparisonErrorMessage = nil

        if resetsVisibleProfile {
            secondaryProfile = nil
        }

        activeComparisonTask = Task { [weak self] in
            guard let self else { return }

            do {
                let comparison = try await service.fetchComparisonProfile(
                    latitude: target.coordinate.latitude,
                    longitude: target.coordinate.longitude,
                    scale: scale == .tract ? .tract : .zip,
                    fallbackTitle: target.fallbackTitle,
                    fallbackSubtitle: target.fallbackSubtitle
                )

                guard isCurrentRequest(requestID) else { return }

                secondaryProfile = ComparablePlaceProfile(
                    id: comparison.id,
                    title: comparison.title,
                    subtitle: comparison.subtitle,
                    metrics: mapDemographicsToMetrics(comparison.demographics),
                    demographics: comparison.demographics,
                    metricsSource: comparison.metricsSource
                )
                pendingComparisonTitle = secondaryProfile?.title
                isLoadingComparison = false
                comparisonErrorMessage = nil
            } catch is CancellationError {
                return
            } catch let serviceError as CensusZipDemographicsService.ServiceError {
                guard isCurrentRequest(requestID) else { return }

                secondaryProfile = nil
                isLoadingComparison = false
                switch serviceError {
                case .noZCTAFound:
                    comparisonErrorMessage = AppStrings.Labels.compareNoCoverageBody
                default:
                    comparisonErrorMessage = AppStrings.Labels.compareLoadFailedBody
                }
            } catch {
                guard isCurrentRequest(requestID) else { return }

                secondaryProfile = nil
                isLoadingComparison = false
                comparisonErrorMessage = AppStrings.Labels.compareLoadFailedBody
            }
        }
    }

    private func mapDemographicsToMetrics(_ demographics: Demographics) -> CensusMetrics {
        CensusMetrics(
            population: demographics.population,
            medianIncome: demographics.medianHouseholdIncome,
            medianAge: demographics.medianAge,
            households: demographics.housingUnits,
            populationTrend: nil,
            ageBuckets: nil,
            educationLevels: nil,
            householdIncome: nil
        )
    }

    private func isCurrentRequest(_ requestID: UUID) -> Bool {
        activeRequestID == requestID
    }

    private static func comparisonID(
        primaryID: String,
        secondaryID: String,
        scale: BoundaryOverlayScale
    ) -> String {
        "\(primaryID)::\(secondaryID)::\(scale.rawValue)"
    }
}

private struct ComparisonTarget {
    let coordinate: CLLocationCoordinate2D
    let fallbackTitle: String
    let fallbackSubtitle: String
    let scale: BoundaryOverlayScale
}
