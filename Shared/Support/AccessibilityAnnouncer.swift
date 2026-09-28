//
//  AccessibilityAnnouncer.swift
//  Lociq
//
//  Speaks important state changes to VoiceOver users.
//

import Accessibility
#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

/// Posts VoiceOver announcements for changes that happen without focus moving.
///
/// Used sparingly: a failure, a refresh result, and a change of view. Every
/// announcement mirrors text that is also visible on screen.
enum AccessibilityAnnouncer {
    /// Announces a message if VoiceOver is running.
    @MainActor
    static func announce(_ message: String) {
        #if os(watchOS)
        guard WKAccessibilityIsVoiceOverRunning(), !message.isEmpty else { return }
        AccessibilityNotification.Announcement(message).post()
        #else
        guard UIAccessibility.isVoiceOverRunning, !message.isEmpty else { return }
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(message).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #endif
    }
}
