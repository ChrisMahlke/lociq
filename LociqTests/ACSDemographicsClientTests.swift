//
//  ACSDemographicsClientTests.swift
//  LociqTests
//
//  Verifies city-level ACS request construction and value normalization.
//

import Foundation
import Testing
@testable import Lociq

@Suite(.serialized)
@MainActor
struct ACSDemographicsClientTests {
    /// Verifies that place-level ACS requests use city/place geography and normalize unavailable estimates.
    @Test func cambridgePlaceRequestUsesCityLevelACSGeography() async throws {
        CambridgeACSURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CambridgeACSURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = ACSDemographicsClient(
            censusApiKey: "test-key",
            acsYear: 2024,
            httpClient: CensusHTTPClient(session: session)
        )

        let demographics = try await client.fetchDemographics(
            place: PlaceInfo(
                name: "Cambridge city, Massachusetts",
                stateFIPS: "25",
                placeFIPS: "11000",
                type: .incorporatedPlace
            )
        )

        let requestedURLs = CambridgeACSURLProtocol.requestedURLs()
        #expect(!requestedURLs.isEmpty)
        for url in requestedURLs {
            #expect(url.queryValue(named: "for") == "place:11000")
            #expect(url.queryValue(named: "in") == "state:25")
        }
        #expect(demographics.name == "Cambridge city, Massachusetts")
        #expect(demographics.population.total == 118_214)
        #expect(demographics.income.medianHousehold == 121_539)
        #expect(demographics.housing.medianHomeValue == nil)
        #expect(demographics.housing.medianGrossRent == nil)
    }

    /// Verifies that census-designated places use the same place-level ACS geography contract.
    @Test func censusDesignatedPlaceRequestUsesPlaceLevelACSGeography() async throws {
        CambridgeACSURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CambridgeACSURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = ACSDemographicsClient(
            censusApiKey: "test-key",
            acsYear: 2024,
            httpClient: CensusHTTPClient(session: session)
        )

        let demographics = try await client.fetchDemographics(
            place: PlaceInfo(
                name: "East Harwich CDP, Massachusetts",
                stateFIPS: "25",
                placeFIPS: "19075",
                type: .censusDesignatedPlace
            )
        )

        let requestedURLs = CambridgeACSURLProtocol.requestedURLs()
        #expect(!requestedURLs.isEmpty)
        for url in requestedURLs {
            #expect(url.queryValue(named: "for") == "place:19075")
            #expect(url.queryValue(named: "in") == "state:25")
        }
        #expect(demographics.name == "East Harwich CDP, Massachusetts")
        #expect(demographics.population.total == 5_112)
    }

    /// Verifies that sparse ACS rows for very small places still produce a valid normalized profile.
    @Test func verySmallPlaceNormalizesSparseACSValues() async throws {
        CambridgeACSURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CambridgeACSURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = ACSDemographicsClient(
            censusApiKey: "test-key",
            acsYear: 2024,
            httpClient: CensusHTTPClient(session: session)
        )

        let demographics = try await client.fetchDemographics(
            place: PlaceInfo(
                name: "Monowi village, Nebraska",
                stateFIPS: "31",
                placeFIPS: "32550",
                type: .incorporatedPlace
            )
        )

        #expect(demographics.name == "Monowi village, Nebraska")
        #expect(demographics.population.total == 1)
        #expect(demographics.income.medianHousehold == nil)
        #expect(demographics.age.median == nil)
    }

    /// Verifies ACS sentinel values and string markers are consistently treated as unavailable.
    @Test func suppressedAndMissingACSValuesNormalizeToUnavailable() {
        #expect(ACSValueNormalizer.int("-666666666") == nil)
        #expect(ACSValueNormalizer.int("N/A") == nil)
        #expect(ACSValueNormalizer.int("  ") == nil)
        #expect(ACSValueNormalizer.double("-999999999") == nil)
        #expect(ACSValueNormalizer.double("null") == nil)
        #expect(ACSValueNormalizer.int("0") == 0)
        #expect(ACSValueNormalizer.double("30.8") == 30.8)
    }
}

private final class CambridgeACSURLProtocol: URLProtocol {
    private static let recorder = URLRequestRecorder()

    /// Accepts mocked Census API requests for the test URL session.
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.census.gov"
    }

    /// Returns the request unchanged because the mock does not need canonicalization.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Serves a generated ACS JSON response for the intercepted request.
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.recorder.append(url)

        do {
            let data = try Self.responseData(for: url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    /// Stops loading; the mock response is synchronous so no cleanup is needed.
    override func stopLoading() {}

    /// Clears recorded requests before a test starts.
    static func reset() {
        recorder.reset()
    }

    /// Returns the Census API URLs observed by the mock.
    static func requestedURLs() -> [URL] {
        recorder.urls()
    }

    /// Builds the ACS row for the variables requested in the URL.
    private static func responseData(for url: URL) throws -> Data {
        let variables = url.queryValue(named: "get")?
            .split(separator: ",")
            .map(String.init) ?? []
        let placeCode = url.queryValue(named: "for")?.replacingOccurrences(of: "place:", with: "") ?? "11000"
        let stateCode = url.queryValue(named: "in")?.replacingOccurrences(of: "state:", with: "") ?? "25"
        let valuesByVariable = valuesByVariable(forPlace: placeCode)
        let header = variables + ["state", "place"]
        let row = variables.map { valuesByVariable[$0, default: "0"] } + [stateCode, placeCode]
        return try JSONSerialization.data(withJSONObject: [header, row])
    }

    /// Provides fixture values keyed by ACS variable code.
    private static func valuesByVariable(forPlace placeCode: String) -> [String: String] {
        switch placeCode {
        case "19075":
            return [
                "NAME": "East Harwich CDP, Massachusetts",
                "B01003_001E": "5112",
                "B19013_001E": "89321",
                "B01002_001E": "52.4"
            ]
        case "32550":
            return [
                "NAME": "Monowi village, Nebraska",
                "B01003_001E": "1",
                "B19013_001E": "N/A",
                "B01002_001E": "null"
            ]
        default:
            return [
            "NAME": "Cambridge city, Massachusetts",
            "B01003_001E": "118214",
            "B19013_001E": "121539",
            "B01002_001E": "30.8",
            "B25077_001E": "-666666666",
            "B25064_001E": "-999999999",
            "B25003_002E": "18000",
            "B25003_003E": "33000",
            "B25002_001E": "54000",
            "B25002_003E": "3000"
            ]
        }
    }
}

private final class URLRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedURLs: [URL] = []

    /// Records one requested URL in a thread-safe array.
    func append(_ url: URL) {
        lock.lock()
        storedURLs.append(url)
        lock.unlock()
    }

    /// Returns a snapshot of recorded URLs.
    func urls() -> [URL] {
        lock.lock()
        let urls = storedURLs
        lock.unlock()
        return urls
    }

    /// Clears all recorded URLs.
    func reset() {
        lock.lock()
        storedURLs = []
        lock.unlock()
    }
}

private extension URL {
    /// Reads a named query value from the URL.
    func queryValue(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }
}
