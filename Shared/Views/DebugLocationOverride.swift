//
//  DebugLocationOverride.swift
//  Lociq
//
//  Provides launch-argument overrides for deterministic local testing.
//
//  Two Debug-only switches exist. `--lociq-debug-cambridge` replaces Core
//  Location with a fixed Cambridge, Massachusetts coordinate and still loads
//  live Census data. `--lociq-ui-fixture <name>` also replaces the Census
//  pipeline with a canned outcome and uses a throwaway cache, so UI tests and
//  screenshots run without network, location, or the real cache. Neither is
//  compiled into Release builds.
//

import CoreLocation
import Foundation

extension LocationProfileViewModel {
    /// Creates the view model for this launch, honoring Debug-only overrides.
    static func makeForLaunch() -> LocationProfileViewModel {
        #if DEBUG
        if let fixture = LociqLaunchFixture.current {
            return fixture.makeViewModel()
        }
        return LocationProfileViewModel(debugCoordinate: DebugLocationOverride.current?.coordinate)
        #else
        return LocationProfileViewModel()
        #endif
    }
}

#if DEBUG
/// Optional coordinate override derived from launch arguments or environment.
struct DebugLocationOverride {
    /// Coordinate used instead of Core Location when the override is active.
    let coordinate: CLLocationCoordinate2D

    /// Reads launch arguments and environment flags for deterministic city testing.
    ///
    /// Supported inputs:
    /// `--lociq-debug-cambridge` as a launch argument, or
    /// `LOCIQ_DEBUG_CITY=cambridge` as an environment variable.
    static var current: DebugLocationOverride? {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment

        if arguments.contains("--lociq-debug-cambridge")
            || environment["LOCIQ_DEBUG_CITY"]?.lowercased() == "cambridge" {
            return DebugLocationOverride(
                coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056)
            )
        }

        return nil
    }
}

/// Canned launch states for UI tests and screenshots, with no network or location.
enum LociqLaunchFixture: String, CaseIterable {
    /// A complete Cambridge, MA profile with a simple boundary and land area.
    case cambridge

    /// A complete profile with a long place name and top-coded medians.
    case longName

    /// The device is offline and no profile is cached.
    case offline

    /// The location is outside every Census place.
    case outsideCityLimits

    /// The Cambridge profile after a one-minute delay, to show the loading stage.
    case slow

    /// Reads `--lociq-ui-fixture <name>` from the launch arguments.
    static var current: LociqLaunchFixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let index = arguments.firstIndex(of: "--lociq-ui-fixture"),
            arguments.indices.contains(index + 1)
        else { return nil }
        return LociqLaunchFixture(rawValue: arguments[index + 1])
    }

    /// True when `--lociq-ui-fixture-details` asks to open the details view at launch.
    ///
    /// Works with or without a fixture, so screenshots of the details view
    /// can also show live Census data.
    static var showsDetailsOnLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("--lociq-ui-fixture-details")
    }

    /// Fixture coordinate (a public landmark, not a user location).
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056)
    }

    /// Builds a view model wired to canned data and a throwaway cache.
    @MainActor
    func makeViewModel() -> LocationProfileViewModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lociq-ui-fixture-\(UUID().uuidString)", isDirectory: true)
        let suiteName = "lociq.ui-fixture.\(UUID().uuidString)"
        return LocationProfileViewModel(
            debugCoordinate: coordinate,
            cacheStore: CityProfileCacheStore(directory: directory, defaults: UserDefaults(suiteName: suiteName) ?? .standard),
            profileLoader: FixtureCityProfileLoader(fixture: self),
            profileResolvedHaptic: {},
            openSettings: {}
        )
    }
}

/// Loader that returns one canned outcome after a short delay.
private struct FixtureCityProfileLoader: CityProfileLoading {
    let fixture: LociqLaunchFixture

    func loadProfile(_ request: CityProfileLoadRequest) async -> CityProfileLoadOutcome {
        try? await Task.sleep(nanoseconds: fixture == .slow ? 60_000_000_000 : 300_000_000)
        switch fixture {
        case .cambridge, .slow:
            return .loaded(profile(for: request, demographics: Self.cambridgeDemographics, placeName: "Cambridge", baseName: "Cambridge", geoid: "2511000"))
        case .longName:
            return .loaded(profile(for: request, demographics: Self.longNameDemographics, placeName: "San Buenaventura (Ventura) city", baseName: "San Buenaventura (Ventura)", geoid: "0665042"))
        case .offline:
            return .unavailable(unavailable(.networkUnavailable, request: request))
        case .outsideCityLimits:
            return .unavailable(unavailable(.cityUnavailable, request: request, countyTitle: "Middlesex County, MA"))
        }
    }

    private func unavailable(_ failure: CityProfileLoadFailure, request: CityProfileLoadRequest, countyTitle: String? = nil) -> CityProfileUnavailable {
        CityProfileUnavailable(
            snapshot: .unavailable(failure, countyTitle: countyTitle),
            coordinate: request.coordinate,
            horizontalAccuracy: request.horizontalAccuracy,
            isApproximate: request.isApproximate,
            failure: failure
        )
    }

    private func profile(
        for request: CityProfileLoadRequest,
        demographics: Demographics,
        placeName: String,
        baseName: String,
        geoid: String
    ) -> CachedCityProfile {
        let place = PlaceInfo(
            name: placeName,
            baseName: baseName,
            stateFIPS: String(geoid.prefix(2)),
            placeFIPS: String(geoid.suffix(5)),
            geoid: geoid,
            type: .incorporatedPlace
        )
        let boundary = Self.boundary(around: request.coordinate, geoid: geoid)
        let resolved = ResolvedCityProfile(
            geography: CityGeographyProfile(county: nil, place: place),
            boundarySet: CityBoundarySet(city: boundary),
            demographics: CityDemographicsBundle(place: demographics)
        )
        return CachedCityProfile(
            snapshot: DemographicSnapshot(profile: resolved, demographics: demographics),
            boundary: boundary,
            latitude: request.coordinate.latitude,
            longitude: request.coordinate.longitude,
            horizontalAccuracy: 65,
            placeGeoid: geoid,
            isApproximate: false
        )
    }

    /// An irregular outline with one enclave around the coordinate.
    private static func boundary(around center: CLLocationCoordinate2D, geoid: String) -> GeoJSONFeatureCollection {
        let lat = center.latitude
        let lon = center.longitude
        let exterior: [[Double]] = [
            [lon - 0.050, lat - 0.020], [lon - 0.010, lat - 0.030], [lon + 0.030, lat - 0.018],
            [lon + 0.040, lat + 0.006], [lon + 0.016, lat + 0.024], [lon - 0.026, lat + 0.020],
            [lon - 0.050, lat - 0.020]
        ]
        let enclave: [[Double]] = [
            [lon + 0.012, lat - 0.012], [lon + 0.020, lat - 0.012], [lon + 0.020, lat - 0.006],
            [lon + 0.012, lat - 0.006], [lon + 0.012, lat - 0.012]
        ]
        return GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [
                GeoJSONFeature(
                    type: "Feature",
                    properties: [
                        "GEOID": .string(geoid),
                        "AREALAND": .string("16567881"),
                        "INTPTLAT": .string(String(lat)),
                        "INTPTLON": .string(String(lon))
                    ],
                    geometry: .polygon([exterior, enclave])
                )
            ]
        )
    }

    private static let cambridgeDemographics = Demographics(
        name: "Cambridge city, Massachusetts",
        population: PopulationDemographics(total: 118_796),
        income: IncomeDemographics(medianHousehold: 128_433),
        age: AgeDemographics(median: 30.8, under18Pct: 12.1, age18To34Pct: 43.2, age35To64Pct: 31.9, age65PlusPct: 12.8),
        housing: HousingDemographics(
            medianHomeValue: 1_044_300,
            medianGrossRent: 2_781,
            ownerOccupied: 17_812,
            renterOccupied: 33_088,
            ownerOccupiedPct: 35.0,
            totalUnits: 54_402,
            vacantUnits: 3_502,
            vacancyRatePct: 6.4
        ),
        education: EducationDemographics(bachelorsOrHigherPct: 81.2),
        mobility: MobilityDemographics(
            workersTotal: 69_864,
            workersWfh: 21_511,
            workersWfhPct: 30.8,
            transitCommuters: 16_240,
            transitCommutersPct: 23.2,
            averageCommuteMinutes: 25.8
        )
    )

    private static let longNameDemographics = Demographics(
        name: "San Buenaventura (Ventura) city, California",
        population: PopulationDemographics(total: 109_910),
        income: IncomeDemographics(medianHousehold: 250_000, medianHouseholdBound: .atLeast),
        age: AgeDemographics(median: 41.2, under18Pct: 19.9, age18To34Pct: 21.4, age35To64Pct: 39.3, age65PlusPct: 19.4),
        housing: HousingDemographics(
            medianHomeValue: 2_000_000,
            medianHomeValueBound: .atLeast,
            medianGrossRent: 3_500,
            medianGrossRentBound: .atLeast,
            ownerOccupied: 22_900,
            renterOccupied: 18_400,
            ownerOccupiedPct: 55.4,
            totalUnits: 43_800,
            vacantUnits: 2_500,
            vacancyRatePct: 5.7
        ),
        education: EducationDemographics(bachelorsOrHigherPct: 38.6),
        mobility: MobilityDemographics(
            workersTotal: 52_000,
            workersWfh: 7_300,
            workersWfhPct: 14.0,
            transitCommuters: 780,
            transitCommutersPct: 1.5,
            averageCommuteMinutes: 23.4
        )
    )
}
#endif
