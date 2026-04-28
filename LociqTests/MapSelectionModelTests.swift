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

    @Test func switchesToPrefetchedTractMetricsWithoutRefreshState() async throws {
        let zipBundle = makeZipBundle()
        let boundaries = makeBoundaries()
        let zipDemographics = makeDemographics(name: "ZIP Demographics", population: 42_000)
        let tractDemographics = makeDemographics(name: "Tract Demographics", population: 12_500)

        let service = StubCensusNeighborhoodService(
            zipBundleResult: .success(zipBundle),
            boundaries: boundaries,
            demographicsByScale: [.zip: zipDemographics, .tract: tractDemographics]
        )
        let model = MapSelectionModel(service: service, libraryStore: makeLibraryStore())

        model.handleMapSelection(CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4))
        await waitUntil { model.selectedZipBundle != nil && model.isBoundaryLoading == false }

        model.selectBoundaryScale(.tract)
        await waitUntil { model.metricsSource == .tract }

        #expect(model.isRefreshingScale == false)
        #expect(model.selectedDemographics?.name == "Tract Demographics")
        #expect(model.censusMetrics?.population == tractDemographics.population)
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

    @Test func keepsExistingSelectionVisibleWhileRefreshingNewSelection() async throws {
        let firstCoordinate = CLLocationCoordinate2D(latitude: 37.78, longitude: -122.4)
        let secondCoordinate = CLLocationCoordinate2D(latitude: 34.05, longitude: -118.24)
        let firstBundle = makeZipBundle(
            zcta: "94107",
            countyName: "San Francisco County",
            tractGeoid: "06075022900",
            tractCode: "022900",
            placeName: "San Francisco",
            demographicsName: "San Francisco ZIP Demographics",
            population: 41_000
        )
        let secondBundle = makeZipBundle(
            zcta: "90012",
            countyName: "Los Angeles County",
            tractGeoid: "06037207500",
            tractCode: "207500",
            placeName: "Los Angeles",
            demographicsName: "Los Angeles ZIP Demographics",
            population: 24_000
        )
        let service = DelayedProfileCensusNeighborhoodService(
            profilesByCoordinate: [
                coordinateKey(firstCoordinate): makeResolvedPlaceProfile(bundle: firstBundle),
                coordinateKey(secondCoordinate): makeResolvedPlaceProfile(bundle: secondBundle)
            ],
            delaysByCoordinate: [
                coordinateKey(secondCoordinate): 150_000_000
            ]
        )
        let model = MapSelectionModel(service: service, libraryStore: makeLibraryStore())

        model.handleMapSelection(firstCoordinate)
        await waitUntil { model.selectedZipCode == "94107" && model.isBoundaryLoading == false }

        model.handleMapSelection(secondCoordinate)
        try? await Task.sleep(nanoseconds: 40_000_000)

        #expect(model.isBoundaryLoading == true)
        #expect(model.selectedZipCode == "94107")
        #expect(model.selectedZipBundle?.place?.name == "San Francisco")
        #expect(model.censusMetrics?.population == 41_000)

        await waitUntil { model.selectedZipCode == "90012" && model.isBoundaryLoading == false }

        #expect(model.selectedZipBundle?.place?.name == "Los Angeles")
        #expect(model.censusMetrics?.population == 24_000)
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

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let bundle = try zipBundleResult.get()
        let tractDemographics: Demographics?

        if let error = demographicsErrorsByScale[.tract] {
            if error is CancellationError {
                throw error
            }
            tractDemographics = nil
        } else {
            tractDemographics = demographicsByScale[.tract]
        }

        return ResolvedPlaceProfile(
            zipBundle: bundle,
            boundaries: boundaries,
            scaleDemographics: ScaleDemographicsBundle(
                zip: demographicsByScale[.zip] ?? bundle.demographics,
                tract: tractDemographics
            )
        )
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

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        let bundle = try zipBundleResult.get()
        let demographics = try await fetchDemographics(
            for: scale,
            zcta: bundle.zcta,
            tractGeoid: bundle.tract?.geoid,
            latitude: latitude,
            longitude: longitude
        )

        return ComparisonProfileResult(
            id: bundle.tract?.geoid ?? bundle.zcta,
            title: bundle.place?.name ?? fallbackTitle,
            subtitle: fallbackSubtitle,
            demographics: demographics,
            metricsSource: scale == .tract ? .tract : .zcta
        )
    }
}

private actor DelayedProfileCensusNeighborhoodService: CensusNeighborhoodServing {
    let profilesByCoordinate: [String: ResolvedPlaceProfile]
    let delaysByCoordinate: [String: UInt64]

    init(
        profilesByCoordinate: [String: ResolvedPlaceProfile],
        delaysByCoordinate: [String: UInt64] = [:]
    ) {
        self.profilesByCoordinate = profilesByCoordinate
        self.delaysByCoordinate = delaysByCoordinate
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let key = coordinateKey(latitude: latitude, longitude: longitude)

        if let delay = delaysByCoordinate[key], delay > 0 {
            try await Task.sleep(nanoseconds: delay)
        }

        guard let profile = profilesByCoordinate[key] else {
            throw CensusZipDemographicsService.ServiceError.noZCTAFound
        }

        return profile
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        try await fetchPlaceProfile(latitude: latitude, longitude: longitude).zipBundle
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
        let key = coordinateKey(latitude: latitude, longitude: longitude)
        return profilesByCoordinate[key]?.boundaries
            ?? NeighborhoodBoundarySet(zip: zipBoundary, tract: nil, block: nil)
    }

    func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        let profile = try await fetchPlaceProfile(latitude: latitude, longitude: longitude)

        switch scale {
        case .zip:
            return profile.scaleDemographics.zip
        case .tract:
            if let tract = profile.scaleDemographics.tract {
                return tract
            }
            throw CensusZipDemographicsService.ServiceError.noDemographicsFound
        }
    }

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        let profile = try await fetchPlaceProfile(latitude: latitude, longitude: longitude)
        let demographics = try await fetchDemographics(
            for: scale,
            zcta: profile.zipBundle.zcta,
            tractGeoid: profile.zipBundle.tract?.geoid,
            latitude: latitude,
            longitude: longitude
        )

        return ComparisonProfileResult(
            id: profile.zipBundle.tract?.geoid ?? profile.zipBundle.zcta,
            title: profile.zipBundle.place?.name ?? fallbackTitle,
            subtitle: fallbackSubtitle,
            demographics: demographics,
            metricsSource: scale == .tract ? .tract : .zcta
        )
    }
}

private func makeZipBundle(
    zcta: String = "94107",
    countyName: String = "San Francisco County",
    tractGeoid: String = "06075022900",
    tractCode: String = "022900",
    placeName: String = "San Francisco",
    demographicsName: String = "ZIP Demographics",
    population: Int = 41_000
) -> ZipLookupResult {
    let zipBoundary = makePolygonFeatureCollection(propertyKey: "ZCTA5", propertyValue: zcta)

    return ZipLookupResult(
        zcta: zcta,
        county: CountyInfo(name: countyName, stateFIPS: "06", countyFIPS: "075", geoid: "06075"),
        tract: TractInfo(name: "Tract \(tractCode)", geoid: tractGeoid, stateFIPS: "06", countyFIPS: "075", tractCode: tractCode),
        place: PlaceInfo(name: placeName, stateFIPS: "06", placeFIPS: "67000", type: .incorporatedPlace),
        isIncorporatedPlace: true,
        boundary: zipBoundary,
        boundaryMetrics: nil,
        demographics: makeDemographics(name: demographicsName, population: population),
        insights: []
    )
}

private func makeResolvedPlaceProfile(bundle: ZipLookupResult) -> ResolvedPlaceProfile {
    ResolvedPlaceProfile(
        zipBundle: bundle,
        boundaries: makeBoundaries(tractGeoid: bundle.tract?.geoid ?? "06075022900"),
        scaleDemographics: ScaleDemographicsBundle(
            zip: bundle.demographics,
            tract: nil
        )
    )
}

private func makeBoundaries(tractGeoid: String = "06075022900") -> NeighborhoodBoundarySet {
    NeighborhoodBoundarySet(
        zip: makePolygonFeatureCollection(propertyKey: "ZCTA5", propertyValue: "94107"),
        tract: makePolygonFeatureCollection(propertyKey: "GEOID", propertyValue: tractGeoid),
        block: nil
    )
}

private func coordinateKey(_ coordinate: CLLocationCoordinate2D) -> String {
    coordinateKey(latitude: coordinate.latitude, longitude: coordinate.longitude)
}

private func coordinateKey(latitude: Double, longitude: Double) -> String {
    String(format: "%.5f,%.5f", latitude, longitude)
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
