//
//  CensusHTTPClientTests.swift
//  LociqTests
//
//  Verifies Census HTTP retry and timeout behavior.
//
//  The tests use custom URL protocols so the HTTP client can be exercised
//  without real Census traffic. They cover the runtime behavior most likely to
//  affect perceived app speed.
//

import Foundation
import Testing
@testable import Lociq

@MainActor
/// Tests for shared Census HTTP transport behavior.
struct CensusHTTPClientTests {
    /// Verifies transient Census HTTP failures are retried before data is returned.
    ///
    /// The mock returns two `500` responses followed by success. The assertion
    /// protects both retry count and final data propagation.
    @Test func retriesTransientHTTPFailuresBeforeReturningData() async throws {
        RetryingURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RetryingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = CensusHTTPClient(
            session: session,
            retryPolicy: CensusRetryPolicy(
                maxAttempts: 3,
                requestTimeoutNanoseconds: 1_000_000_000,
                baseBackoffNanoseconds: 1_000_000
            )
        )

        let url = try #require(URL(string: "https://api.census.gov/test"))
        let data = try await client.get(url)

        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(RetryingURLProtocol.requestCount() == 3)
    }

    /// Verifies a slow Census response is classified as a timeout.
    ///
    /// The mock never calls its client completion methods. The HTTP client must
    /// still return by racing the request against its timeout task.
    @Test func slowRequestProducesTimeoutFailure() async throws {
        HangingURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = CensusHTTPClient(
            session: session,
            retryPolicy: CensusRetryPolicy(
                maxAttempts: 1,
                requestTimeoutNanoseconds: 40_000_000,
                baseBackoffNanoseconds: 1_000_000
            )
        )

        let url = try #require(URL(string: "https://api.census.gov/slow"))

        do {
            _ = try await client.get(url)
            Issue.record("Expected timeout failure")
        } catch let error as CensusServiceError {
            #expect(error == .timedOut)
        }
    }
}

/// URL protocol that fails twice and succeeds on the third attempt.
private final class RetryingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var count = 0

    /// Accepts mocked Census API requests for the test URL session.
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.census.gov"
    }

    /// Returns the request unchanged because the mock does not need canonicalization.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Serves two retryable failures followed by one successful response.
    ///
    /// HTTP `500` is retryable according to `CensusServiceError.isRetryable`.
    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let attempt = Self.count
        Self.lock.unlock()

        let statusCode = attempt < 3 ? 500 : 200
        let body = attempt < 3 ? Data("temporary".utf8) : Data("ok".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    /// Stops loading; the mock response is synchronous so no cleanup is needed.
    override func stopLoading() {}

    /// Clears recorded attempts.
    static func reset() {
        lock.lock()
        count = 0
        lock.unlock()
    }

    /// Returns the number of attempted requests.
    static func requestCount() -> Int {
        lock.lock()
        let count = count
        lock.unlock()
        return count
    }
}

/// URL protocol that intentionally never completes.
///
/// This simulates a hung network or service call so timeout behavior can be
/// tested without sleeping for a real production timeout interval.
private final class HangingURLProtocol: URLProtocol {
    /// Accepts mocked Census API requests for the test URL session.
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.census.gov"
    }

    /// Returns the request unchanged because the mock does not need canonicalization.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Intentionally never completes to exercise client-side timeout handling.
    override func startLoading() {}

    /// Stops loading after the client cancels the timed-out request.
    override func stopLoading() {}

    /// Clears protocol state; this protocol has no state but mirrors other mocks.
    static func reset() {}
}
