import CoreLocation
import Testing
@testable import Lociq

struct NeighborhoodDiscoveryServiceTests {
    @Test func buildsHeuristicRecommendations() async throws {
        let service = NeighborhoodDiscoveryService(censusService: StubDiscoveryCensusService())

        let seedSnapshot = NeighborhoodLookupSnapshot(
            id: "seed",
            title: "Seed Place",
            subtitle: "Seed County · ZIP 94107",
            zipCode: "94107",
            latitude: 37.7749,
            longitude: -122.4194,
            preferredScale: .zip
        )

        let result = try await service.discoverNeighborhoods(
            from: NeighborhoodDiscoverySeed(
                snapshot: seedSnapshot,
                profile: makeDiscoveryProfile(
                    id: "seed",
                    title: "Seed Place",
                    zip: "94107",
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    population: 40_000,
                    income: 100_000,
                    age: 35.0,
                    households: 16_000,
                    homeValue: 900_000,
                    rent: 2_900,
                    ownerOccupiedPct: 52,
                    remoteWorkPct: 16,
                    povertyPct: 10
                )
            ),
            recentPlaces: []
        )

        #expect(result.source == DiscoveryGenerationSource.heuristic)
        #expect(result.recommendations.count == 3)
        #expect(Set(result.recommendations.map { $0.destination.id }).count == 3)
        #expect(!result.summary.isEmpty)
    }
}

private final class StubDiscoveryCensusService: @unchecked Sendable, CensusNeighborhoodServing {
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let latTag = Int((latitude * 1000).rounded())
        let lonTag = abs(Int((longitude * 1000).rounded()))
        let population = 24_000 + abs(latTag % 9_000)
        let income = 72_000 + abs(lonTag % 38_000)
        let age = 29.0 + Double(abs((latTag + lonTag) % 11))
        let households = 9_000 + abs(lonTag % 5_000)
        let homeValue = 620_000 + abs(latTag % 240_000)
        let rent = 2_100 + abs(lonTag % 700)
        let ownerOccupiedPct = 38.0 + Double(abs(latTag % 25))
        let remoteWorkPct = 9.0 + Double(abs(lonTag % 14))
        let povertyPct = 6.0 + Double(abs((latTag + lonTag) % 9))

        return makeDiscoveryProfile(
            id: "\(latTag)-\(lonTag)",
            title: "Candidate \(abs(latTag % 100))",
            zip: String(90000 + abs(lonTag % 999)),
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            population: population,
            income: income,
            age: age,
            households: households,
            homeValue: homeValue,
            rent: rent,
            ownerOccupiedPct: ownerOccupiedPct,
            remoteWorkPct: remoteWorkPct,
            povertyPct: povertyPct
        )
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let profile = try await fetchPlaceProfile(latitude: latitude, longitude: longitude)
        return profile.zipBundle
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        place: PlaceInfo?,
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
        let profile = try await fetchPlaceProfile(latitude: latitude, longitude: longitude)
        return profile.zipBundle.demographics
    }

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        let profile = try await fetchPlaceProfile(latitude: latitude, longitude: longitude)
        return ComparisonProfileResult(
            id: profile.zipBundle.zcta,
            title: fallbackTitle,
            subtitle: fallbackSubtitle,
            demographics: profile.zipBundle.demographics,
            metricsSource: .zcta
        )
    }
}

private func makeDiscoveryProfile(
    id: String,
    title: String,
    zip: String,
    coordinate: CLLocationCoordinate2D,
    population: Int,
    income: Int,
    age: Double,
    households: Int,
    homeValue: Int,
    rent: Int,
    ownerOccupiedPct: Double,
    remoteWorkPct: Double,
    povertyPct: Double
) -> ResolvedPlaceProfile {
    let demographics = Demographics(
        name: title,
        population: population,
        medianHouseholdIncome: income,
        medianAge: age,
        housingUnits: households,
        medianHomeValue: homeValue,
        medianGrossRent: rent,
        averageHouseholdSize: 2.5,
        ownerOccupied: Int(Double(households) * ownerOccupiedPct / 100),
        renterOccupied: Int(Double(households) * (100 - ownerOccupiedPct) / 100),
        ownerOccupiedPct: ownerOccupiedPct,
        renterOccupiedPct: 100 - ownerOccupiedPct,
        workersTotal: households,
        workersWfh: Int(Double(households) * remoteWorkPct / 100),
        workersWfhPct: remoteWorkPct,
        povertyUniverse: population,
        povertyBelow: Int(Double(population) * povertyPct / 100),
        povertyRatePct: povertyPct,
        whiteAlone: Int(Double(population) * 0.4),
        blackAlone: Int(Double(population) * 0.1),
        asianAlone: Int(Double(population) * 0.2),
        hispanicOrLatino: Int(Double(population) * 0.2)
    )

    let bundle = ZipLookupResult(
        zcta: zip,
        county: CountyInfo(name: "Seed County", stateFIPS: nil, countyFIPS: nil, geoid: nil),
        tract: TractInfo(name: nil, geoid: "tract-\(id)", stateFIPS: nil, countyFIPS: nil, tractCode: "000100"),
        place: PlaceInfo(name: title, stateFIPS: nil, placeFIPS: nil, type: .unknown),
        isIncorporatedPlace: false,
        boundary: GeoJSONFeatureCollection(type: "FeatureCollection", features: []),
        boundaryMetrics: nil,
        demographics: demographics,
        insights: []
    )

    return ResolvedPlaceProfile(
        zipBundle: bundle,
        boundaries: NeighborhoodBoundarySet(
            zip: GeoJSONFeatureCollection(type: "FeatureCollection", features: []),
            tract: nil,
            block: nil
        ),
        scaleDemographics: ScaleDemographicsBundle(
            zip: demographics,
            tract: demographics
        )
    )
}
