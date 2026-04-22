//
//  LociqFirebaseRuntime.swift
//  Lociq
//
//  Process-local guards for temporarily disabling Firebase-backed flows when
//  the client bootstrap is misconfigured.
//

import Foundation

enum LociqFirebaseRuntime {
    private static let lock = NSLock()
    private static var disabledReason: String?

    static var isCallableBackendEnabled: Bool {
        guard AppConfig.useFirebaseLociqBackend else {
            return false
        }

        lock.lock()
        defer { lock.unlock() }
        return disabledReason == nil
    }

    static var currentDisabledReason: String? {
        lock.lock()
        defer { lock.unlock() }
        return disabledReason
    }

    static func clearDisableReason() {
        lock.lock()
        disabledReason = nil
        lock.unlock()
    }

    static func disableForCurrentSession(reason: String) {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        if disabledReason == nil {
            disabledReason = trimmed
        }
        lock.unlock()
    }
}
