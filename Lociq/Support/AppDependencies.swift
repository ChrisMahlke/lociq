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
    let neighborhoodLibraryStore: NeighborhoodLibraryStore

    static let live = AppDependencies(
        makeCensusLookupService: {
            CensusZipDemographicsService(censusApiKey: AppConfig.censusAPIKey)
        },
        makePlaceSearchService: {
            ApplePlaceSearchService()
        },
        neighborhoodLibraryStore: NeighborhoodLibraryStore()
    )
}
