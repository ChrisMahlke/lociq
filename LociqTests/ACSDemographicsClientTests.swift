import Foundation
import Testing
@testable import Lociq

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
        #expect(demographics.population == 118_214)
        #expect(demographics.medianHouseholdIncome == 121_539)
        #expect(demographics.medianHomeValue == nil)
        #expect(demographics.medianGrossRent == nil)
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
        let valuesByVariable = cambridgeValuesByVariable()
        let header = variables + ["state", "place"]
        let row = variables.map { valuesByVariable[$0, default: "0"] } + ["25", "11000"]
        return try JSONSerialization.data(withJSONObject: [header, row])
    }

    /// Provides fixture values keyed by ACS variable code.
    private static func cambridgeValuesByVariable() -> [String: String] {
        [
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
