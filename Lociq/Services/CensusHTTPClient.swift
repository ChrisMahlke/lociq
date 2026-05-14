//
//  CensusHTTPClient.swift
//  Lociq
//
//  Provides shared HTTP and JSON decoding behavior for Census-backed services.
//

import Foundation

struct CensusHTTPClient: Sendable {
    private let session: URLSession
    private let retryPolicy: CensusRetryPolicy

    /// Creates a Census HTTP client backed by an injectable URL session.
    init(session: URLSession, retryPolicy: CensusRetryPolicy = .live) {
        self.session = session
        self.retryPolicy = retryPolicy
    }

    /// Performs an HTTP GET and throws when the Census service returns a non-success status.
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
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CensusServiceError.decodeFailed(error.localizedDescription)
        }
    }
}
