//
//  BottomIdentity.swift
//  Lociq
//
//  Renders the LOC IQ mark, bottom action, and loading line.
//

import SwiftUI

struct BottomIdentity: View {
    private enum Constants {
        static let brandLeading = "LOC"
        static let brandTrailing = "IQ"
        static let brandAccessibilityLabel = "LOCIQ"
        static let brandAccessibilityIdentifier = "app.brand"
        static let summaryAccessibilityIdentifier = "demographics.summary"
        static let locationIcon = "location"
        static let retryIcon = "arrow.clockwise"
        static let homeIcon = "house"
        static let detailIcon = "list.bullet.rectangle"
        static let enableLocationLabel = "Enable location access"
        static let retryLabel = "Retry loading data"
        static let showHomeLabel = "Show home view"
        static let showDataLabel = "Show data view"
    }

    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool
    let isLoading: Bool
    let isWaitingForInitialData: Bool
    let canRetry: Bool
    let needsLocationPermission: Bool
    let canRefresh: Bool
    let shareText: String?
    let layout: MinimalLayout
    var reduceMotion = false
    let onShowDetails: () -> Void
    let onRefresh: () -> Void

    private var iconName: String {
        if !snapshot.hasDemographicData {
            return needsLocationPermission ? Constants.locationIcon : Constants.retryIcon
        }
        return isShowingDetails ? Constants.homeIcon : Constants.detailIcon
    }

    private var actionLabel: String {
        if !snapshot.hasDemographicData {
            return needsLocationPermission ? Constants.enableLocationLabel : Constants.retryLabel
        }
        return isShowingDetails ? Constants.showHomeLabel : Constants.showDataLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(Constants.brandLeading)
                        Text(Constants.brandTrailing)
                    }
                    .font(LociqTypeScale.brand(layout))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Constants.brandAccessibilityLabel)
                    .accessibilityIdentifier(Constants.brandAccessibilityIdentifier)

                    Spacer(minLength: 28)

                    if !isWaitingForInitialData && (snapshot.hasDemographicData || canRetry) {
                        Button(action: onShowDetails) {
                            Image(systemName: iconName)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .frame(width: 44, height: 44)
                                .opacity(isLoading ? 0.42 : 1)
                                .id(iconName)
                                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .accessibilityLabel(actionLabel)
                        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: iconName)
                        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: isLoading)
                        .contextMenu {
                            if canRefresh {
                                Button("Refresh", systemImage: Constants.retryIcon, action: onRefresh)
                            }
                            if let shareText {
                                ShareLink(item: shareText) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                }

                ProgressLine(progress: snapshot.confidence, isLoading: isLoading, reduceMotion: reduceMotion)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if canRetry {
                            onShowDetails()
                        }
                    }
            }
            .frame(maxWidth: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Constants.summaryAccessibilityIdentifier)
    }
}
