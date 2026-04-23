import CoreLocation
import Testing
@testable import Lociq

@MainActor
struct CompareModeModelTests {
    @Test func loadsComparisonProfileForZipScale() async {
        let service = StubCompareNeighborhoodService(zipBundleResult: .success(makeCompareZipBundle()))
        let model = CompareModeModel(service: service)
        let result = PlaceSearchResult(
            title: "Oakland",
            subtitle: "Alameda County, CA",
            coordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2711)
        )

        model.beginComparison(with: result, scale: .zip)
        await waitUntil { model.secondaryProfile != nil && model.isLoadingComparison == false }

        #expect(model.secondaryProfile?.title == "Oakland")
        #expect(model.secondaryProfile?.metricsSource == .zcta)
        #expect(model.secondaryProfile?.metrics.population == 55_000)
    }

    @Test func refreshesComparisonForScaleChanges() async {
        let zipDemographics = makeCompareDemographics(name: "ZIP Area", population: 55_000, income: 98_000)
        let tractDemographics = makeCompareDemographics(name: "Tract Area", population: 8_800, income: 121_000)
        let service = StubCompareNeighborhoodService(
            zipBundleResult: .success(makeCompareZipBundle(demographics: zipDemographics)),
            demographicsByScale: [.zip: zipDemographics, .tract: tractDemographics]
        )
        let model = CompareModeModel(service: service)
        let result = PlaceSearchResult(
            title: "Oakland",
            subtitle: "Alameda County, CA",
            coordinate: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2711)
        )

        model.beginComparison(with: result, scale: .zip)
        await waitUntil { model.secondaryProfile?.metrics.population == 55_000 }

        model.refreshComparison(for: .tract)
        await waitUntil { model.secondaryProfile?.metrics.population == 8_800 }

        #expect(model.secondaryProfile?.metricsSource == .tract)
        #expect(model.secondaryProfile?.metrics.medianIncome == 121_000)
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

private actor StubCompareNeighborhoodService: CensusNeighborhoodServing {
    let zipBundleResult: Result<ZipLookupResult, Error>
    let demographicsByScale: [NeighborhoodScale: Demographics]

    init(
        zipBundleResult: Result<ZipLookupResult, Error>,
        demographicsByScale: [NeighborhoodScale: Demographics] = [.zip: makeCompareDemographics(name: "ZIP Area", population: 55_000, income: 98_000)]
    ) {
        self.zipBundleResult = zipBundleResult
        self.demographicsByScale = demographicsByScale
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let bundle = try zipBundleResult.get()
        return ResolvedPlaceProfile(
            zipBundle: bundle,
            boundaries: NeighborhoodBoundarySet(zip: bundle.boundary, tract: nil, block: nil),
            scaleDemographics: ScaleDemographicsBundle(
                zip: demographicsByScale[.zip] ?? bundle.demographics,
                tract: demographicsByScale[.tract]
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
        NeighborhoodBoundarySet(zip: zipBoundary, tract: nil, block: nil)
    }

    func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
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
        let demographics: Demographics
        let metricsSource: MetricsSource

        switch scale {
        case .zip:
            demographics = demographicsByScale[.zip] ?? bundle.demographics
            metricsSource = .zcta
        case .tract:
            if let tract = demographicsByScale[.tract] {
                demographics = tract
                metricsSource = .tract
            } else {
                demographics = demographicsByScale[.zip] ?? bundle.demographics
                metricsSource = .zcta
            }
        }

        return ComparisonProfileResult(
            id: bundle.tract?.geoid ?? bundle.zcta,
            title: bundle.place?.name ?? fallbackTitle,
            subtitle: fallbackSubtitle,
            demographics: demographics,
            metricsSource: metricsSource
        )
    }
}

private func makeCompareZipBundle(demographics: Demographics = makeCompareDemographics(name: "ZIP Area", population: 55_000, income: 98_000)) -> ZipLookupResult {
    let boundary = GeoJSONFeatureCollection(
        type: "FeatureCollection",
        features: [
            GeoJSONFeature(
                type: "Feature",
                properties: ["ZCTA5": "94607" as String?],
                geometry: .polygon([
                    [
                        [-122.28, 37.81],
                        [-122.26, 37.81],
                        [-122.26, 37.79],
                        [-122.28, 37.79],
                        [-122.28, 37.81]
                    ]
                ])
            )
        ]
    )

    return ZipLookupResult(
        zcta: "94607",
        county: CountyInfo(name: "Alameda County", stateFIPS: "06", countyFIPS: "001", geoid: "06001"),
        tract: TractInfo(name: "Tract 983200", geoid: "06001983200", stateFIPS: "06", countyFIPS: "001", tractCode: "983200"),
        place: PlaceInfo(name: "Oakland", stateFIPS: "06", placeFIPS: "53000", type: .incorporatedPlace),
        isIncorporatedPlace: true,
        boundary: boundary,
        boundaryMetrics: nil,
        demographics: demographics,
        insights: []
    )
}

private func makeCompareDemographics(name: String, population: Int, income: Int) -> Demographics {
    Demographics(
        name: name,
        population: population,
        medianHouseholdIncome: income,
        medianAge: 35.5,
        housingUnits: 19_500,
        medianHomeValue: 880_000,
        medianGrossRent: 2_350,
        averageHouseholdSize: 2.5,
        ownerOccupied: 7_200,
        renterOccupied: 9_600,
        ownerOccupiedPct: 42.8,
        renterOccupiedPct: 57.2,
        workersTotal: 21_000,
        workersWfh: 4_200,
        workersWfhPct: 20,
        povertyUniverse: 49_000,
        povertyBelow: 6_800,
        povertyRatePct: 13.9,
        whiteAlone: 12_000,
        blackAlone: 13_500,
        asianAlone: 8_200,
        hispanicOrLatino: 14_000
    )
}
