//
//  LociqCommands.swift
//  Lociq
//
//  Adds LOC IQ's commands to the iPad menu bar and to keyboard shortcuts.
//
//  The window's root view publishes what it can do as a focused scene value;
//  the commands read it, so the menu always matches the screen. With a
//  hardware keyboard, holding Command lists the shortcuts.
//

import SwiftUI

/// What the menu bar and keyboard shortcuts can do in the key window.
struct LociqCommandActions {
    /// True when Refresh can run.
    let canRefresh: Bool

    /// Finds the location and reloads Census data.
    let refresh: () -> Void

    /// True when the summary and the details take turns on screen. False
    /// without a profile, and when the details are already beside the summary.
    let canSwitchView: Bool

    /// True while the details are shown.
    let isShowingDetails: Bool

    /// Shows the details (`true`) or the summary (`false`).
    let showDetails: (Bool) -> Void

    /// Current appearance.
    let themePreference: LociqThemePreference

    /// Changes the appearance.
    let selectTheme: (LociqThemePreference) -> Void
}

/// Focused-value key for `LociqCommandActions`.
private struct LociqCommandActionsKey: FocusedValueKey {
    typealias Value = LociqCommandActions
}

extension FocusedValues {
    /// Commands published by the key window's root view.
    var lociqCommandActions: LociqCommandActions? {
        get { self[LociqCommandActionsKey.self] }
        set { self[LociqCommandActionsKey.self] = newValue }
    }
}

/// View menu commands: Summary (⌘1), Details (⌘2), Refresh (⌘R), and Appearance.
///
/// ⌘1 and ⌘2 follow the convention for switching a window's view, and ⌘R
/// the one for reloading.
struct LociqCommands: Commands {
    @FocusedValue(\.lociqCommandActions) private var actions

    var body: some Commands {
        // LOC IQ shows one place, where you are, so it has no New Window command.
        CommandGroup(replacing: .newItem) {}

        CommandGroup(before: .toolbar) {
            Button("Summary") { actions?.showDetails(false) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(!canSwitchView || actions?.isShowingDetails != true)

            Button("Details") { actions?.showDetails(true) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(!canSwitchView || actions?.isShowingDetails != false)

            Divider()

            Button("Refresh") { actions?.refresh() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions?.canRefresh != true)

            Divider()

            Picker("Appearance", selection: themeBinding) {
                ForEach(LociqThemePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .disabled(actions == nil)
        }
    }

    private var canSwitchView: Bool {
        actions?.canSwitchView == true
    }

    private var themeBinding: Binding<LociqThemePreference> {
        Binding(
            get: { actions?.themePreference ?? .dark },
            set: { actions?.selectTheme($0) }
        )
    }
}
