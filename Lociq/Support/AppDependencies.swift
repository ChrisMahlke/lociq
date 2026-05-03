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

    static let live: AppDependencies = {
        let censusLookupService = CensusZipDemographicsService(censusApiKey: AppConfig.censusAPIKey)
        let libraryStore = NeighborhoodLibraryStore()

        return AppDependencies(
            makeCensusLookupService: {
                censusLookupService
            },
            makePlaceSearchService: {
                ApplePlaceSearchService()
            },
            makeNeighborhoodDiscoveryService: {
                NeighborhoodDiscoveryService(
                    censusService: censusLookupService,
                    geminiClient: GeminiDiscoveryClient.makeDefaultIfAvailable()
                )
            },
            neighborhoodLibraryStore: libraryStore
        )
    }()
}
