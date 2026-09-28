//
//  ViewCompatibility.swift
//  Lociq
//
//  Bridges SwiftUI APIs that differ between the iOS 16 and watchOS 10 targets.
//

import SwiftUI

extension View {
    /// Runs `action` with the new value whenever `value` changes.
    ///
    /// The one-argument `onChange` that iOS 16 needs was deprecated in
    /// watchOS 10, the Apple Watch app's first release, which uses the
    /// two-argument form instead.
    func onChangeOf<Value: Equatable>(_ value: Value, perform action: @escaping (Value) -> Void) -> some View {
        #if os(watchOS)
        onChange(of: value) { _, newValue in action(newValue) }
        #else
        onChange(of: value, perform: action)
        #endif
    }
}
