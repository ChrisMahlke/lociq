//
//  CensusHTTPClient.swift
//  Lociq
//
//  Provides shared HTTP and JSON decoding behavior for Census-backed services.
//
//  Census clients all need the same transport behavior: retry transient
//  failures, enforce a per-request timeout, classify service errors, and decode
//  JSON consistently. This type centralizes those rules.
//

import Foundation

/// Shared HTTP transport for Census geocoder, ACS, and TIGERweb clients.
///
/// The client is intentionally small and does not know about any specific
/// endpoint. Endpoint clients provide URLs and response model types.
struct CensusHTTPClient: Sendable {
    /// Injected URL session, which lets tests provide protocol-backed responses.
    private let session: URLSession

    /// Retry, timeout, and backoff configuration.
    private let retryPolicy: CensusRetryPolicy

    /// Creates a Census HTTP client backed by an injectable URL session.
    init(session: URLSession, retryPolicy: CensusRetryPolicy = .live) {
        self.session = session
        self.retryPolicy = retryPolicy
    }

    /// Performs an HTTP GET and throws when the Census service returns a non-success status.
    ///
    /// Retryable failures are retried according to `retryPolicy`. Non-retryable
    /// failures, such as invalid URLs or decode failures, surface immediately.
    func get(_ url: URL) async throws -> Data {
        var lastError: CensusServiceError?

        for attempt in 0..<retryPolicy.maxAttempts {
            do {
                return try await getOnce(url)
            } catch let error as CensusServiceError {
                lastError = error
                guard error.isRetryable, attempt < retryPolicy.maxAttempts - 1 else { throw error }
                try? await Task.sleep(nanoseconds: retryPolicy.backoffDelay(afterFailedAttempt: attempt))
            } catch {
                let serviceError = CensusServiceError.transport(error)
                lastError = serviceError
                guard serviceError.isRetryable, attempt < retryPolicy.maxAttempts - 1 else { throw serviceError }
                try? await Task.sleep(nanoseconds: retryPolicy.backoffDelay(afterFailedAttempt: attempt))
            }
        }

        throw lastError ?? CensusServiceError.networkUnavailable("Request failed")
    }

    /// Performs one timeout-bounded HTTP GET attempt.
    ///
    /// This method handles only one network attempt. The caller is responsible
    /// for retrying when the resulting `CensusServiceError` says retry may help.
    private func getOnce(_ url: URL) async throws -> Data {
        let (data, response) = try await withTimeout {
            try await session.data(from: url)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CensusServiceError.requestFailed(status: -1, bodySnippet: "Non-HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw CensusServiceError.requestFailed(status: http.statusCode, bodySnippet: String(snippet))
        }

        return data
    }

    /// Runs an async operation with the configured per-request timeout.
    ///
    /// A throwing task group races the operation against a sleeping timeout
    /// task. Once one task finishes, the other is cancelled. This avoids waiting
    /// indefinitely on slow Census services and keeps the UI loading state
    /// bounded.
    private func withTimeout<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let timeout = retryPolicy.requestTimeoutNanoseconds
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeout)
                throw CensusServiceError.timedOut
            }

            guard let result = try await group.next() else {
                throw CensusServiceError.timedOut
            }
            group.cancelAll()
            return result
        }
    }

    /// Decodes JSON data using the shared decoder behavior for Census service responses.
    ///
    /// Decoding errors are wrapped in `CensusServiceError.decodeFailed` so upper
    /// layers can classify all Census failures through one error type.
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CensusServiceError.decodeFailed(error.localizedDescription)
        }
    }
}
