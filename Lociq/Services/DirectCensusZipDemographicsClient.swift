//
//  DirectCensusZipDemographicsClient.swift
//  Lociq
//
//  Coordinates Census, TIGERweb, and FCC-backed neighborhood lookup clients.
//

import Foundation

final class DirectCensusZipDemographicsClient: @unchecked Sendable {
    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private let blockClient: FCCBlockClient
    private let demographicsClient: ACSDemographicsClient

    nonisolated init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        let httpClient = CensusHTTPClient(session: session)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
        blockClient = FCCBlockClient(httpClient: httpClient)
        demographicsClient = ACSDemographicsClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            httpClient: httpClient
        )
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let geo = try await geocoderClient.fetchGeographiesFromCoordinate(latitude: latitude, longitude: longitude)

        async let boundaryTask = boundaryClient.fetchZCTABoundaryGeoJSON(zcta: geo.zcta)
        async let demographicsTask = demographicsClient.fetchDemographics(zcta: geo.zcta)

        let boundary = try await boundaryTask
        let demographics = try await demographicsTask
        let boundaryMetrics = BoundaryAnalyzer.metrics(from: boundary)
        let isIncorporated = geo.place?.type == .incorporatedPlace

        return ZipLookupResult(
            zcta: geo.zcta,
            county: geo.county,
            tract: geo.tract,
            place: geo.place,
            isIncorporatedPlace: isIncorporated,
            boundary: boundary,
            boundaryMetrics: boundaryMetrics,
            demographics: demographics,
            insights: []
        )
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let bundle = try await fetchZipBundle(latitude: latitude, longitude: longitude)
        let cityBoundary = await boundaryClient.fetchPlaceBoundary(place: bundle.place)
        let placeDemographics = try? await fetchPlaceDemographics(place: bundle.place)
        let boundaries = NeighborhoodBoundarySet(
            zip: bundle.boundary,
            city: cityBoundary,
            tract: nil,
            blockGroup: nil,
            block: nil
        )

        return ResolvedPlaceProfile(
            zipBundle: bundle,
            boundaries: boundaries,
            scaleDemographics: ScaleDemographicsBundle(
                place: placeDemographics,
                zip: bundle.demographics,
                tract: nil,
                blockGroup: nil
            )
        )
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        place: PlaceInfo?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
        let blockFIPS = try? await blockClient.fetchBlockFIPS(latitude: latitude, longitude: longitude)
        let tractToUse = tractGeoidFromBlockFIPS(blockFIPS) ?? tractGeoid
        let blockGroupToUse = blockGroupGeoidFromBlockFIPS(blockFIPS)

        async let cityBoundaryTask = boundaryClient.fetchPlaceBoundary(place: place)
        async let tractBoundaryTask = boundaryClient.fetchTractBoundary(tractGeoid: tractToUse)
        async let blockGroupBoundaryTask = boundaryClient.fetchBlockGroupBoundary(blockGroupGeoid: blockGroupToUse)
        async let blockBoundaryTask = boundaryClient.fetchBlockBoundary(blockFIPS: blockFIPS)

        return await NeighborhoodBoundarySet(
            zip: zipBoundary,
            city: cityBoundaryTask,
            tract: tractBoundaryTask,
            blockGroup: blockGroupBoundaryTask,
            block: blockBoundaryTask
        )
    }

    func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        switch scale {
        case .zip:
            return try await demographicsClient.fetchDemographics(zcta: zcta)
        case .tract:
            let blockFIPS = try? await blockClient.fetchBlockFIPS(latitude: latitude, longitude: longitude)
            guard let tract = tractGeoidFromBlockFIPS(blockFIPS) ?? tractGeoid, tract.count >= 11 else {
                throw CensusZipDemographicsService.ServiceError.noDemographicsFound
            }

            return try await demographicsClient.fetchDemographics(tractGeoid: tract)
        }
    }

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        let bundle = try await fetchZipBundle(latitude: latitude, longitude: longitude)
        let demographics: Demographics
        let metricsSource: MetricsSource

        switch scale {
        case .zip:
            demographics = bundle.demographics
            metricsSource = .zcta
        case .tract:
            if let tractDemographics = try? await fetchDemographics(
                for: .tract,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: latitude,
                longitude: longitude
            ) {
                demographics = tractDemographics
                metricsSource = .tract
            } else {
                demographics = bundle.demographics
                metricsSource = .zcta
            }
        }

        return ComparisonProfileResult(
            id: bundle.tract?.geoid ?? bundle.zcta,
            title: makeComparisonTitle(bundle: bundle, fallbackTitle: fallbackTitle),
            subtitle: makeComparisonSubtitle(bundle: bundle, fallbackSubtitle: fallbackSubtitle),
            demographics: demographics,
            metricsSource: metricsSource
        )
    }

    private func tractGeoidFromBlockFIPS(_ blockFIPS: String?) -> String? {
        guard let blockFIPS, blockFIPS.count >= 11 else { return nil }
        return String(blockFIPS.prefix(11))
    }

    private func blockGroupGeoidFromBlockFIPS(_ blockFIPS: String?) -> String? {
        guard let blockFIPS, blockFIPS.count >= 12 else { return nil }
        return String(blockFIPS.prefix(12))
    }

    private func fetchBlockGroupDemographics(blockFIPS: String?) async throws -> Demographics {
        guard let blockGroupGeoid = blockGroupGeoidFromBlockFIPS(blockFIPS) else {
            throw CensusZipDemographicsService.ServiceError.noDemographicsFound
        }

        return try await demographicsClient.fetchDemographics(blockGroupGeoid: blockGroupGeoid)
    }

    private func fetchPlaceDemographics(place: PlaceInfo?) async throws -> Demographics {
        guard let place else {
            throw CensusZipDemographicsService.ServiceError.noDemographicsFound
        }

        return try await demographicsClient.fetchDemographics(place: place)
    }

    private func makeComparisonTitle(bundle: ZipLookupResult, fallbackTitle: String) -> String {
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

    private func makeComparisonSubtitle(bundle: ZipLookupResult, fallbackSubtitle: String) -> String {
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

        return parts.isEmpty ? fallbackSubtitle : parts.joined(separator: " · ")
    }
}
