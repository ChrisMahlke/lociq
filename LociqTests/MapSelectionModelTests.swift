import CoreLocation
import Testing
@testable import Lociq

@MainActor
struct MapSelectionModelTests {
    @Test func fallsBackToSampleMetricsWhenPrimaryLookupFails() async throws {
        let service = StubCensusNeighborhoodService(
            zipBundleResult: .failure(CensusZipDemographicsService.ServiceError.requestFailed(status: 500, bodySnippet: "boom"))
        )
        let model = MapSelectionModel(service: service, libraryStore: makeLibraryStore())

        model.handleMapSelection(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4))
        await waitUntil { model.metricsSource == .sample }

        #expect(model.selectedZipCode == nil)
        #expect(model.metricsSource == .sample)
        #expect(model.censusMetrics?.population != nil)
        #expect(model.selectedBoundary == nil)
        #expect(model.isBoundaryLoading == false)
    }

    @Test func fallsBackToZipDemographicsWhenTractFetchFails() async throws {
        let zipBundle = makeZipBundle()
        let boundaries = makeBoundaries()
        let zipDemographics = makeDemographics(name: "ZIP Demographics", population: 42_000)

        let service = StubCensusNeighborhoodService(
            zipBundleResult: .success(zipBundle),
            boundaries: boundaries,
            demographicsByScale: [.zip: zipDemographics],
            demographicsErrorsByScale: [.tract: CensusZipDemographicsService.ServiceError.noDemographicsFound]
        )
        let model = MapSelectionModel(service: service, libraryStore: makeLibraryStore())

        model.handleMapSelection(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4))
        await waitUntil { model.selectedZipBundle != nil && model.isBoundaryLoading == false }

        model.selectBoundaryScale(.tract)
        await waitUntil { model.metricsSource == .zcta && model.boundaryScale == .tract }

        #expect(model.boundaryScale == .tract)
        #expect(model.metricsSource == .zcta)
        #expect(model.selectedDemographics?.name == "ZIP Demographics")
        #expect(model.selectedBoundary?.features.count == boundaries.tract?.features.count)
    }

    @Test func exposesNoCoverageStateWhenLocationHasNoZipProfile() async throws {
        let service = StubCensusNeighborhoodService(
            zipBundleResult: .failure(CensusZipDemographicsService.ServiceError.noZCTAFound)
        )
        let model = MapSelectionModel(service: service, libraryStore: makeLibraryStore())

        model.handleMapSelection(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4))
        await waitUntil { model.selectionFeedbackState == .noCoverage }

        #expect(model.selectionFeedbackState == .noCoverage)
        #expect(model.censusMetrics == nil)
        #expect(model.selectedZipBundle == nil)
        #expect(model.isBoundaryLoading == false)
    }

    @Test func marksScaleRefreshWhileKeepingCurrentProfileVisible() async throws {
        let zipBundle = makeZipBundle()
        let boundaries = makeBoundaries()
        let zipDemographics = makeDemographics(name: "ZIP Demographics", population: 42_000)
        let tractDemographics = makeDemographics(name: "Tract Demographics", population: 12_500)

        let service = StubCensusNeighborhoodService(
            zipBundleResult: .success(zipBundle),
            boundaries: boundaries,
            demographicsByScale: [.zip: zipDemographics, .tract: tractDemographics],
            demographicsDelayNanoseconds: 200_000_000
        )
        let model = MapSelectionModel(service: service, libraryStore: makeLibraryStore())

        model.handleMapSelection(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4))
        await waitUntil { model.selectedZipBundle != nil && model.isBoundaryLoading == false }

        model.selectBoundaryScale(.tract)
        await waitUntil { model.isRefreshingScale }

        #expect(model.isRefreshingScale == true)
        #expect(model.censusMetrics?.population == zipBundle.demographics.population)

        await waitUntil { model.metricsSource == .tract && model.isRefreshingScale == false }
        #expect(model.selectedDemographics?.name == "Tract Demographics")
    }

    @Test func recordsSuccessfulLookupsInNeighborhoodLibrary() async throws {
        let zipBundle = makeZipBundle()
        let store = makeLibraryStore()
        let service = StubCensusNeighborhoodService(zipBundleResult: .success(zipBundle))
        let model = MapSelectionModel(service: service, libraryStore: store)

        model.handleMapSelection(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4))
        await waitUntil { model.selectedZipBundle != nil && model.recentLookups.count == 1 }

        #expect(model.recentLookups.first?.title == "San Francisco")
        #expect(model.isCurrentPlaceSaved == false)

        model.toggleSavedCurrentPlace()

        #expect(model.isCurrentPlaceSaved == true)
        #expect(model.savedPlaces.count == 1)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let interval: UInt64 = 20_000_000
        var elapsed: UInt64 = 0

        while elapsed < timeoutNanoseconds {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }
    }
}

@MainActor
private func makeLibraryStore() -> NeighborhoodLibraryStore {
    let suiteName = "MapSelectionModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "library")
}

private actor StubCensusNeighborhoodService: CensusNeighborhoodServing {
    let zipBundleResult: Result<ZipLookupResult, Error>
    let boundaries: NeighborhoodBoundarySet
    let demographicsByScale: [NeighborhoodScale: Demographics]
    let demographicsErrorsByScale: [NeighborhoodScale: Error]
    let demographicsDelayNanoseconds: UInt64

    init(
        zipBundleResult: Result<ZipLookupResult, Error>,
        boundaries: NeighborhoodBoundarySet = makeBoundaries(),
        demographicsByScale: [NeighborhoodScale: Demographics] = [.zip: makeDemographics(name: "Zip Area", population: 20_000)],
        demographicsErrorsByScale: [NeighborhoodScale: Error] = [:],
        demographicsDelayNanoseconds: UInt64 = 0
    ) {
        self.zipBundleResult = zipBundleResult
        self.boundaries = boundaries
        self.demographicsByScale = demographicsByScale
        self.demographicsErrorsByScale = demographicsErrorsByScale
        self.demographicsDelayNanoseconds = demographicsDelayNanoseconds
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        try zipBundleResult.get()
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
        boundaries
    }

    func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        if demographicsDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: demographicsDelayNanoseconds)
        }

        if let error = demographicsErrorsByScale[scale] {
            throw error
        }

        if let demographics = demographicsByScale[scale] {
            return demographics
        }

        throw CensusZipDemographicsService.ServiceError.noDemographicsFound
    }
}

private func makeZipBundle() -> ZipLookupResult {
    let zipBoundary = makePolygonFeatureCollection(propertyKey: "ZCTA5", propertyValue: "94107")

    return ZipLookupResult(
        zcta: "94107",
        county: CountyInfo(name: "San Francisco County", stateFIPS: "06", countyFIPS: "075", geoid: "06075"),
        tract: TractInfo(name: "Tract 022900", geoid: "06075022900", stateFIPS: "06", countyFIPS: "075", tractCode: "022900"),
        place: PlaceInfo(name: "San Francisco", stateFIPS: "06", placeFIPS: "67000", type: .incorporatedPlace),
        isIncorporatedPlace: true,
        boundary: zipBoundary,
        boundaryMetrics: nil,
        demographics: makeDemographics(name: "ZIP Demographics", population: 41_000),
        insights: []
    )
}

private func makeBoundaries() -> NeighborhoodBoundarySet {
    NeighborhoodBoundarySet(
        zip: makePolygonFeatureCollection(propertyKey: "ZCTA5", propertyValue: "94107"),
        tract: makePolygonFeatureCollection(propertyKey: "GEOID", propertyValue: "06075022900"),
        block: nil
    )
}

private func makePolygonFeatureCollection(propertyKey: String, propertyValue: String) -> GeoJSONFeatureCollection {
    GeoJSONFeatureCollection(
        type: "FeatureCollection",
        features: [
            GeoJSONFeature(
                type: "Feature",
                properties: [propertyKey: propertyValue as String?],
                geometry: .polygon([
                    [
                        [-122.405, 37.785],
                        [-122.395, 37.785],
                        [-122.395, 37.775],
                        [-122.405, 37.775],
                        [-122.405, 37.785]
                    ]
                ])
            )
        ]
    )
}

private func makeDemographics(name: String, population: Int) -> Demographics {
    Demographics(
        name: name,
        population: population,
        medianHouseholdIncome: 120_000,
        medianAge: 36,
        housingUnits: 18_000,
        medianHomeValue: 1_100_000,
        medianGrossRent: 2_800,
        averageHouseholdSize: 2.4,
        ownerOccupied: 9_000,
        renterOccupied: 7_000,
        ownerOccupiedPct: 56,
        renterOccupiedPct: 44,
        workersTotal: 15_000,
        workersWfh: 3_000,
        workersWfhPct: 20,
        povertyUniverse: 38_000,
        povertyBelow: 4_000,
        povertyRatePct: 10.5,
        whiteAlone: 18_000,
        blackAlone: 2_000,
        asianAlone: 9_000,
        hispanicOrLatino: 6_000
    )
}
