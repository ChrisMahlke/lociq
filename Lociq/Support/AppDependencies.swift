//
//  AppDependencies.swift
//  Lociq
//
//  Small dependency container for app-scoped service construction.
//

import Foundation

struct AppDependencies {
    let makeCensusLookupService: @Sendable () -> any CensusNeighborhoodServing
    let makePlaceSearchService: @Sendable () -> any PlaceSearchServing
    let makeNeighborhoodDiscoveryService: @Sendable () -> any NeighborhoodDiscoveryServing
    let neighborhoodLibraryStore: NeighborhoodLibraryStore

    static let live = AppDependencies(
        makeCensusLookupService: {
            CensusZipDemographicsService(censusApiKey: AppConfig.censusAPIKey)
        },
        makePlaceSearchService: {
            ApplePlaceSearchService()
        },
        makeNeighborhoodDiscoveryService: {
            NeighborhoodDiscoveryService(
                censusService: CensusZipDemographicsService(censusApiKey: AppConfig.censusAPIKey),
                geminiClient: GeminiDiscoveryClient.makeDefaultIfAvailable()
            )
        },
        neighborhoodLibraryStore: NeighborhoodLibraryStore()
    )
}
