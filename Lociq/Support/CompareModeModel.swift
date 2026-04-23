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
            fallbackSubtitle: result.subtitle
        )
        selectedTarget = target
        loadComparison(for: target, scale: scale, resetsVisibleProfile: true)
    }

    func refreshComparison(for scale: BoundaryOverlayScale) {
        guard let selectedTarget else { return }
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
                let bundle = try await service.fetchZipBundle(
                    latitude: target.coordinate.latitude,
                    longitude: target.coordinate.longitude
                )

                guard isCurrentRequest(requestID) else { return }

                let (demographics, source) = try await fetchDemographicsWithFallback(
                    bundle: bundle,
                    coordinate: target.coordinate,
                    scale: scale
                )

                guard isCurrentRequest(requestID) else { return }

                secondaryProfile = ComparablePlaceProfile(
                    id: bundle.tract?.geoid ?? bundle.zcta,
                    title: makeTitle(bundle: bundle, fallbackTitle: target.fallbackTitle),
                    subtitle: makeSubtitle(bundle: bundle, fallbackSubtitle: target.fallbackSubtitle),
                    metrics: mapDemographicsToMetrics(demographics),
                    demographics: demographics,
                    metricsSource: source
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

    private func fetchDemographicsWithFallback(
        bundle: ZipLookupResult,
        coordinate: CLLocationCoordinate2D,
        scale: BoundaryOverlayScale
    ) async throws -> (Demographics, MetricsSource) {
        switch scale {
        case .zip:
            let demographics = try await service.fetchDemographics(
                for: .zip,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            return (demographics, .zcta)
        case .tract:
            if let tractDemographics = try? await service.fetchDemographics(
                for: .tract,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ) {
                return (tractDemographics, .tract)
            }

            let zipFallback = try await service.fetchDemographics(
                for: .zip,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            return (zipFallback, .zcta)
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

    private func makeTitle(bundle: ZipLookupResult, fallbackTitle: String) -> String {
        if let placeName = bundle.place?.name, !placeName.isEmpty {
            return placeName
        }
        if !bundle.demographics.name.isEmpty {
            return bundle.demographics.name
        }
        if !bundle.zcta.isEmpty {
            return AppStrings.Formats.zip(bundle.zcta)
        }
        return fallbackTitle
    }

    private func makeSubtitle(bundle: ZipLookupResult, fallbackSubtitle: String) -> String {
        var parts: [String] = []

        if let countyName = bundle.county?.name, !countyName.isEmpty {
            parts.append(countyName)
        }
        if !bundle.zcta.isEmpty {
            parts.append(AppStrings.Formats.zip(bundle.zcta))
        }
        if let tractCode = bundle.tract?.tractCode, !tractCode.isEmpty {
            parts.append(AppStrings.Formats.tract(tractCode))
        }

        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }

        return fallbackSubtitle
    }

    private func isCurrentRequest(_ requestID: UUID) -> Bool {
        activeRequestID == requestID
    }
}

private struct ComparisonTarget {
    let coordinate: CLLocationCoordinate2D
    let fallbackTitle: String
    let fallbackSubtitle: String
}
