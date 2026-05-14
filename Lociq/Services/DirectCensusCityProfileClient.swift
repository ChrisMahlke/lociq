//
//  DirectCensusCityProfileClient.swift
//  Lociq
//
//  Coordinates Census geocoding, ACS demographics, and TIGER city boundaries.
//

import Foundation

final class DirectCensusCityProfileClient: @unchecked Sendable {
    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private let demographicsClient: ACSDemographicsClient

    /// Creates the direct Census client by composing geocoder, ACS, and TIGERweb dependencies over one session.
    nonisolated init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        let httpClient = CensusHTTPClient(session: session)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
        demographicsClient = ACSDemographicsClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            httpClient: httpClient
        )
    }

    /// Resolves a coordinate into one city-level profile with place demographics and boundary geometry.
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedCityProfile {
        let geographies = try await geocoderClient.fetchGeographiesFromCoordinate(
            latitude: latitude,
            longitude: longitude
        )
        let geography = CityGeographyProfile(
            county: geographies.county,
            place: geographies.place
        )

        async let cityBoundaryTask = boundaryClient.fetchPlaceBoundary(place: geography.place)
        async let placeDemographicsTask = fetchPlaceDemographics(place: geography.place)

        return await ResolvedCityProfile(
            geography: geography,
            boundarySet: CityBoundarySet(city: cityBoundaryTask),
            demographics: CityDemographicsBundle(
                place: try? placeDemographicsTask
            )
        )
    }

    /// Fetches demographics for a resolved place or throws when no place is available.
    private func fetchPlaceDemographics(place: PlaceInfo?) async throws -> Demographics {
        guard let place else {
            throw CensusServiceError.noDemographicsFound
        }

        return try await demographicsClient.fetchDemographics(place: place)
    }
}
