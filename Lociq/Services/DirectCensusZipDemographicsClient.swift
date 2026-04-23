//
//  DirectCensusZipDemographicsClient.swift
//  Lociq
//
//  Direct Census, TIGERweb, and FCC-backed neighborhood lookup implementation.
//

import Foundation

final class DirectCensusZipDemographicsClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let censusApiKey: String
    private let session: URLSession
    private let acsYear: Int

    private let geocoderBenchmark = "Public_AR_Current"
    private let geocoderVintage = "Current_Current"
    private let zctaLayerId = "2"
    private let tractLayerId = "8"
    private let countyLayerId = "82"
    private let incorporatedPlacesLayerId = "28"
    private let cdpLayerId = "30"
    private let blockLayerId = "12"

    private let geocoderCoordinatesURL = "https://geocoding.geo.census.gov/geocoder/geographies/coordinates"
    private let tigerwebMapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"

    init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        self.censusApiKey = censusApiKey
        self.acsYear = acsYear
        self.session = session
    }

    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let geo = try await fetchGeographiesFromCoordinate(latitude: latitude, longitude: longitude)

        async let boundaryTask = fetchZCTABoundaryGeoJSON(zcta: geo.zcta)
        async let demographicsTask = fetchACSDemographics(zcta: geo.zcta)

        let boundary = try await boundaryTask
        let demographics = try await demographicsTask
        let boundaryMetrics = BoundaryAnalyzer.metrics(from: boundary)

        let isIncorporated = geo.place?.type == .incorporatedPlace
        let insights = InsightEngine.makeInsights(
            zcta: geo.zcta,
            county: geo.county,
            tract: geo.tract,
            isIncorporatedPlace: isIncorporated,
            boundaryMetrics: boundaryMetrics,
            demographics: demographics
        )

        return ZipLookupResult(
            zcta: geo.zcta,
            county: geo.county,
            tract: geo.tract,
            place: geo.place,
            isIncorporatedPlace: isIncorporated,
            boundary: boundary,
            boundaryMetrics: boundaryMetrics,
            demographics: demographics,
            insights: insights
        )
    }

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let bundle = try await fetchZipBundle(latitude: latitude, longitude: longitude)
        let boundaries = await fetchNeighborhoodBoundaries(
            latitude: latitude,
            longitude: longitude,
            tractGeoid: bundle.tract?.geoid,
            zipBoundary: bundle.boundary
        )

        let tractDemographics = try? await fetchDemographics(
            for: .tract,
            zcta: bundle.zcta,
            tractGeoid: bundle.tract?.geoid,
            latitude: latitude,
            longitude: longitude
        )

        return ResolvedPlaceProfile(
            zipBundle: bundle,
            boundaries: boundaries,
            scaleDemographics: ScaleDemographicsBundle(
                zip: bundle.demographics,
                tract: tractDemographics
            )
        )
    }

    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
        let blockFIPS = try? await fetchBlockFIPS(latitude: latitude, longitude: longitude)
        let tractGeoidFromBlock: String?

        if let blockFIPS, blockFIPS.count >= 11 {
            tractGeoidFromBlock = String(blockFIPS.prefix(11))
        } else {
            tractGeoidFromBlock = nil
        }

        let tractToUse = tractGeoidFromBlock ?? tractGeoid

        async let tractBoundaryTask: GeoJSONFeatureCollection? = fetchTractBoundary(tractGeoid: tractToUse)
        async let blockBoundaryTask: GeoJSONFeatureCollection? = fetchBlockBoundary(blockFIPS: blockFIPS)

        return await NeighborhoodBoundarySet(
            zip: zipBoundary,
            tract: tractBoundaryTask,
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
            return try await fetchACSDemographics(zcta: zcta)
        case .tract:
            let blockFIPS = try? await fetchBlockFIPS(latitude: latitude, longitude: longitude)
            let tractFromBlock: String?

            if let blockFIPS, blockFIPS.count >= 11 {
                tractFromBlock = String(blockFIPS.prefix(11))
            } else {
                tractFromBlock = nil
            }

            guard let tract = tractFromBlock ?? tractGeoid, tract.count >= 11 else {
                throw CensusZipDemographicsService.ServiceError.noDemographicsFound
            }

            return try await fetchACSDemographics(tractGeoid: tract)
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

    private struct GeographiesBundle: Sendable {
        let zcta: String
        let county: CountyInfo?
        let tract: TractInfo?
        let place: PlaceInfo?
    }

    private func fetchGeographiesFromCoordinate(latitude: Double, longitude: Double) async throws -> GeographiesBundle {
        var components = URLComponents(string: geocoderCoordinatesURL)
        components?.queryItems = [
            .init(name: "x", value: String(longitude)),
            .init(name: "y", value: String(latitude)),
            .init(name: "benchmark", value: geocoderBenchmark),
            .init(name: "vintage", value: geocoderVintage),
            .init(
                name: "layers",
                value: [
                    zctaLayerId,
                    countyLayerId,
                    tractLayerId,
                    incorporatedPlacesLayerId,
                    cdpLayerId
                ].joined(separator: ",")
            ),
            .init(name: "format", value: "json")
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)
        let decoded = try decode(CensusGeocoderResponse.self, from: data)

        return GeographiesBundle(
            zcta: try extractZCTA(from: decoded),
            county: extractCountyInfo(from: decoded),
            tract: extractTractInfo(from: decoded),
            place: extractPlaceInfo(from: decoded)
        )
    }

    private func extractZCTA(from decoded: CensusGeocoderResponse) throws -> String {
        let zctaKey = "2020 Census ZIP Code Tabulation Areas"

        if let value = decoded.result?.geographies?[zctaKey]?.first?.ZCTA5, value.count == 5 {
            return value
        }

        if let geographies = decoded.result?.geographies {
            for (_, geos) in geographies {
                if let found = geos.first?.ZCTA5, found.count == 5 {
                    return found
                }
            }
        }

        throw ServiceError.noZCTAFound
    }

    private func extractCountyInfo(from decoded: CensusGeocoderResponse) -> CountyInfo? {
        guard let geographies = decoded.result?.geographies else { return nil }

        if let county = geographies["Counties"]?.first {
            return CountyInfo(
                name: county.NAME ?? county.BASENAME ?? "County",
                stateFIPS: county.STATE,
                countyFIPS: county.COUNTY,
                geoid: county.GEOID
            )
        }

        for (_, entries) in geographies {
            if let first = entries.first, first.COUNTY != nil {
                return CountyInfo(
                    name: first.NAME ?? first.BASENAME ?? "County",
                    stateFIPS: first.STATE,
                    countyFIPS: first.COUNTY,
                    geoid: first.GEOID
                )
            }
        }

        return nil
    }

    private func extractTractInfo(from decoded: CensusGeocoderResponse) -> TractInfo? {
        guard let geographies = decoded.result?.geographies else { return nil }

        if let tract = geographies["Census Tracts"]?.first {
            let geoid = tract.GEOID
            return TractInfo(
                name: tract.NAME ?? tract.BASENAME,
                geoid: geoid,
                stateFIPS: tract.STATE,
                countyFIPS: tract.COUNTY,
                tractCode: tract.TRACT ?? geoid.map { String($0.suffix(6)) }
            )
        }

        for (_, entries) in geographies {
            if let first = entries.first, let tract = first.TRACT {
                return TractInfo(
                    name: first.NAME ?? first.BASENAME,
                    geoid: first.GEOID,
                    stateFIPS: first.STATE,
                    countyFIPS: first.COUNTY,
                    tractCode: tract
                )
            }

            if let first = entries.first, let geoid = first.GEOID, geoid.count == 11 {
                return TractInfo(
                    name: first.NAME ?? first.BASENAME,
                    geoid: geoid,
                    stateFIPS: first.STATE,
                    countyFIPS: first.COUNTY,
                    tractCode: String(geoid.suffix(6))
                )
            }
        }

        return nil
    }

    private func extractPlaceInfo(from decoded: CensusGeocoderResponse) -> PlaceInfo? {
        guard let geographies = decoded.result?.geographies else { return nil }

        if let incorporated = geographies["Incorporated Places"]?.first,
           let name = incorporated.NAME ?? incorporated.BASENAME,
           !name.isEmpty {
            return PlaceInfo(
                name: name,
                stateFIPS: incorporated.STATE,
                placeFIPS: incorporated.PLACE,
                type: .incorporatedPlace
            )
        }

        if let cdp = geographies["Census Designated Places"]?.first,
           let name = cdp.NAME ?? cdp.BASENAME,
           !name.isEmpty {
            return PlaceInfo(
                name: name,
                stateFIPS: cdp.STATE,
                placeFIPS: cdp.PLACE,
                type: .censusDesignatedPlace
            )
        }

        for (_, entries) in geographies {
            if let first = entries.first,
               let name = first.NAME ?? first.BASENAME,
               !name.isEmpty,
               first.PLACE != nil {
                return PlaceInfo(
                    name: name,
                    stateFIPS: first.STATE,
                    placeFIPS: first.PLACE,
                    type: .unknown
                )
            }
        }

        return nil
    }

    private func fetchZCTABoundaryGeoJSON(zcta: String) async throws -> GeoJSONFeatureCollection {
        guard isValid(value: zcta, regex: AppStrings.Validation.zipRegex) else {
            throw ServiceError.noBoundaryFound
        }

        return try await fetchBoundaryGeoJSON(
            layerId: zctaLayerId,
            whereClause: "ZCTA5='\(zcta)'",
            outFields: "ZCTA5,GEOID,NAME"
        )
    }

    private func fetchTractBoundary(tractGeoid: String?) async -> GeoJSONFeatureCollection? {
        guard let tractGeoid, isValid(value: tractGeoid, regex: AppStrings.Validation.tractRegex) else {
            return nil
        }

        return try? await fetchBoundaryGeoJSON(
            layerId: tractLayerId,
            whereClause: "GEOID='\(tractGeoid)'",
            outFields: "GEOID,NAME"
        )
    }

    private func fetchBlockBoundary(blockFIPS: String?) async -> GeoJSONFeatureCollection? {
        guard
            let blockFIPS,
            blockFIPS.count == 15,
            isValid(value: blockFIPS, regex: AppStrings.Validation.blockRegex)
        else {
            return nil
        }

        return try? await fetchBoundaryGeoJSON(
            layerId: blockLayerId,
            whereClause: "GEOID='\(blockFIPS)'",
            outFields: "GEOID,NAME"
        )
    }

    private func fetchBlockFIPS(latitude: Double, longitude: Double) async throws -> String {
        var components = URLComponents(string: AppStrings.Network.fccCensusURL)
        components?.queryItems = [
            .init(name: AppStrings.QueryItems.latitude, value: String(latitude)),
            .init(name: AppStrings.QueryItems.longitude, value: String(longitude)),
            .init(name: AppStrings.QueryItems.responseFormat, value: AppStrings.Network.jsonFormat)
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)
        let decoded = try decode(FCCBlockResponse.self, from: data)

        guard let fips = decoded.Block?.fips, !fips.isEmpty else {
            throw ServiceError.noBoundaryFound
        }

        return fips
    }

    private func fetchBoundaryGeoJSON(layerId: String, whereClause: String, outFields: String) async throws -> GeoJSONFeatureCollection {
        var components = URLComponents(string: "\(tigerwebMapServerBaseURL)/\(layerId)/query")
        components?.queryItems = [
            .init(name: "where", value: whereClause),
            .init(name: "outFields", value: outFields),
            .init(name: "returnGeometry", value: "true"),
            .init(name: "outSR", value: "4326"),
            .init(name: "f", value: "geojson")
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)
        let featureCollection = try decode(GeoJSONFeatureCollection.self, from: data)

        guard !featureCollection.features.isEmpty else {
            throw ServiceError.noBoundaryFound
        }

        return featureCollection
    }

    private func fetchACSDemographics(zcta: String) async throws -> Demographics {
        try await fetchACSDemographics(
            forQuery: "zip code tabulation area:\(zcta)",
            inQuery: nil,
            fallbackName: AppStrings.Formats.zip(zcta),
            variables: acsExtendedVariables
        )
    }

    private func fetchACSDemographics(tractGeoid: String) async throws -> Demographics {
        let state = String(tractGeoid.prefix(2))
        let county = String(tractGeoid.dropFirst(2).prefix(3))
        let tract = String(tractGeoid.suffix(6))

        return try await fetchACSDemographics(
            forQuery: "tract:\(tract)",
            inQuery: "state:\(state)+county:\(county)",
            fallbackName: AppStrings.Formats.tract(tractGeoid),
            variables: acsExtendedVariables
        )
    }

    private var acsExtendedVariables: [String] {
        [
            "NAME",
            "B01003_001E",
            "B19013_001E",
            "B01002_001E",
            "B25001_001E",
            "B25077_001E",
            "B25064_001E",
            "B25010_001E",
            "B25003_002E",
            "B25003_003E",
            "B08301_001E",
            "B08301_021E",
            "B17001_001E",
            "B17001_002E",
            "B02001_002E",
            "B02001_003E",
            "B02001_005E",
            "B03003_003E"
        ]
    }

    private func fetchACSDemographics(
        forQuery: String,
        inQuery: String?,
        fallbackName: String,
        variables: [String]
    ) async throws -> Demographics {
        let baseURL = "https://api.census.gov/data/\(acsYear)/acs/acs5"
        var components = URLComponents(string: baseURL)
        var queryItems: [URLQueryItem] = [
            .init(name: "get", value: variables.joined(separator: ",")),
            .init(name: "for", value: forQuery)
        ]

        if let inQuery {
            queryItems.append(.init(name: "in", value: inQuery))
        }

        if !censusApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(.init(name: "key", value: censusApiKey))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)

        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [[String]],
            top.count >= 2
        else {
            throw ServiceError.decodeFailed("Unexpected ACS response shape")
        }

        let header = top[0]
        let row = top[1]
        guard header.count == row.count else {
            throw ServiceError.decodeFailed("Header/row length mismatch")
        }

        var valuesByKey: [String: String] = [:]
        for (key, value) in zip(header, row) {
            valuesByKey[key] = value
        }

        func intValue(_ key: String) -> Int? {
            guard let value = valuesByKey[key], let intValue = Int(value) else { return nil }
            return intValue
        }

        func doubleValue(_ key: String) -> Double? {
            guard let value = valuesByKey[key], let doubleValue = Double(value) else { return nil }
            return doubleValue
        }

        func percent(_ numerator: Int?, _ denominator: Int?) -> Double? {
            guard let numerator, let denominator, denominator > 0 else { return nil }
            return (Double(numerator) / Double(denominator)) * 100.0
        }

        guard valuesByKey["B01003_001E"] != nil else {
            throw ServiceError.noDemographicsFound
        }

        let owner = intValue("B25003_002E")
        let renter = intValue("B25003_003E")
        let occupancyTotal: Int? = {
            guard let owner, let renter else { return nil }
            return owner + renter
        }()

        let workersTotal = intValue("B08301_001E")
        let workersWfh = intValue("B08301_021E")
        let povertyUniverse = intValue("B17001_001E")
        let povertyBelow = intValue("B17001_002E")

        return Demographics(
            name: valuesByKey["NAME"] ?? fallbackName,
            population: intValue("B01003_001E"),
            medianHouseholdIncome: intValue("B19013_001E"),
            medianAge: doubleValue("B01002_001E"),
            housingUnits: intValue("B25001_001E"),
            medianHomeValue: intValue("B25077_001E"),
            medianGrossRent: intValue("B25064_001E"),
            averageHouseholdSize: doubleValue("B25010_001E"),
            ownerOccupied: owner,
            renterOccupied: renter,
            ownerOccupiedPct: percent(owner, occupancyTotal),
            renterOccupiedPct: percent(renter, occupancyTotal),
            workersTotal: workersTotal,
            workersWfh: workersWfh,
            workersWfhPct: percent(workersWfh, workersTotal),
            povertyUniverse: povertyUniverse,
            povertyBelow: povertyBelow,
            povertyRatePct: percent(povertyBelow, povertyUniverse),
            whiteAlone: intValue("B02001_002E"),
            blackAlone: intValue("B02001_003E"),
            asianAlone: intValue("B02001_005E"),
            hispanicOrLatino: intValue("B03003_003E")
        )
    }

    private func httpGET(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed(status: -1, bodySnippet: "Non-HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw ServiceError.requestFailed(status: http.statusCode, bodySnippet: String(snippet))
        }

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ServiceError.decodeFailed(error.localizedDescription)
        }
    }
}

private extension DirectCensusZipDemographicsClient {
    func isValid(value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }

    func makeComparisonTitle(bundle: ZipLookupResult, fallbackTitle: String) -> String {
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

    func makeComparisonSubtitle(bundle: ZipLookupResult, fallbackSubtitle: String) -> String {
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

        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }

        return fallbackSubtitle
    }
}

private struct CensusGeocoderResponse: Codable {
    let result: CensusGeocoderResult?
}

private struct CensusGeocoderResult: Codable {
    let geographies: [String: [CensusGeocoderGeography]]?
}

private struct CensusGeocoderGeography: Codable {
    let ZCTA5: String?
    let NAME: String?
    let BASENAME: String?
    let GEOID: String?
    let STATE: String?
    let COUNTY: String?
    let TRACT: String?
    let PLACE: String?
}
