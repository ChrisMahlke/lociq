//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationProfile: LocationProfileViewModel
    @State private var isShowingDetails = false
    @State private var isLoadingContent = false

    init() {
        _locationProfile = StateObject(
            wrappedValue: LocationProfileViewModel(debugCoordinate: DebugLocationOverride.current?.coordinate)
        )
    }

    private var activeCoordinate: CLLocationCoordinate2D? {
        locationProfile.coordinate
    }

    private var displaySnapshot: DemographicSnapshot {
        locationProfile.snapshot
    }

    private var canShowBoundary: Bool {
        locationProfile.canShowBoundary
    }

    private var isWaitingForInitialData: Bool {
        locationProfile.isWaitingForInitialData
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(54, geometry.safeAreaInsets.top + 34)
            let bottomReserve: CGFloat = geometry.size.height < 520 ? 168 : 190
            let detailHeight = max(120, geometry.size.height - topInset - bottomReserve)

            ZStack(alignment: .topTrailing) {
                MinimalBackground()

                if canShowBoundary, let boundary = locationProfile.boundary {
                    ZipBoundaryPreview(
                        boundary: boundary,
                        coordinate: activeCoordinate,
                        traceToken: locationProfile.traceToken
                    )
                        .frame(
                            width: min(max(geometry.size.width * 0.28, 96), 142),
                            height: min(max(geometry.size.height * 0.19, 112), 158)
                        )
                        .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                            BoundaryCityConnectionAnchors(boundary: $0)
                        }
                        .padding(.top, topInset + 96)
                        .padding(.leading, 30)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityLabel("City boundary")
                }

                if !isWaitingForInitialData {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .trailing, spacing: 34) {
                            HeaderBlock(snapshot: displaySnapshot)

                            FadingContentPanel(
                                snapshot: displaySnapshot,
                                isShowingDetails: isShowingDetails
                            )
                            .frame(
                                maxWidth: isShowingDetails ? min(geometry.size.width * 0.50, 246) : .infinity,
                                alignment: .trailing
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(
                        maxWidth: min(geometry.size.width * 0.64, 340),
                        maxHeight: detailHeight,
                        alignment: .topTrailing
                    )
                    .padding(.top, topInset)
                    .padding(.trailing, 28)
                }

                BottomIdentity(
                    snapshot: displaySnapshot,
                    isShowingDetails: isShowingDetails,
                    isLoading: isLoadingContent || locationProfile.isLoading,
                    isWaitingForInitialData: isWaitingForInitialData
                ) {
                    cycleContent()
                }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlayPreferenceValue(BoundaryCityConnectionPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    if let boundaryAnchor = anchors.boundary, let cityAnchor = anchors.city {
                        let boundaryRect = proxy[boundaryAnchor]
                        let cityRect = proxy[cityAnchor]
                        let boundaryPathCenter = GeoJSONBoundaryPathBuilder.center(
                            for: locationProfile.boundary,
                            fallbackRect: boundaryRect
                        )
                        BoundaryCityConnectorLine(
                            start: CGPoint(
                                x: boundaryRect.minX + boundaryPathCenter.x,
                                y: boundaryRect.minY + boundaryPathCenter.y
                            ),
                            end: CGPoint(x: cityRect.minX - 9, y: cityRect.midY),
                            traceToken: locationProfile.traceToken
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .background(Color.lociqInk)
        .preferredColorScheme(.dark)
        .onAppear {
            locationProfile.activate()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            locationProfile.activate()
        }
    }

    private func cycleContent() {
        guard !isLoadingContent else { return }
        guard displaySnapshot.hasDemographicData else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            isLoadingContent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeInOut(duration: 0.62)) {
                isShowingDetails.toggle()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeInOut(duration: 0.32)) {
                isLoadingContent = false
            }
        }
    }
}

private struct DebugLocationOverride {
    let coordinate: CLLocationCoordinate2D

    static var current: DebugLocationOverride? {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment

        if arguments.contains("--lociq-debug-cambridge")
            || environment["LOCIQ_DEBUG_CITY"]?.lowercased() == "cambridge" {
            return DebugLocationOverride(
                coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056)
            )
        }

        return nil
    }
}

private struct MinimalBackground: View {
    var body: some View {
        ZStack {
            Color.lociqInk

            Rectangle()
                .fill(Color.white.opacity(0.045))
                .frame(width: 260)
                .rotationEffect(.degrees(-31))
                .offset(x: 84, y: -150)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.035),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 142)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct HeaderBlock: View {
    let snapshot: DemographicSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(snapshot.market)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                    BoundaryCityConnectionAnchors(city: $0)
                }

            if !snapshot.dateLabel.isEmpty {
                Text(snapshot.dateLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demographics.header")
    }
}

private struct MetricBlock: View {
    let metric: DemographicMetric

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(metric.title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text(metric.primaryValue)
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(metric.detail)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BottomIdentity: View {
    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool
    let isLoading: Bool
    let isWaitingForInitialData: Bool
    let onShowDetails: () -> Void

    private var iconName: String {
        isShowingDetails ? "house" : "list.bullet.rectangle"
    }

    private var actionLabel: String {
        isShowingDetails ? "Show home view" : "Show data view"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("LOC")
                        Text("IQ")
                    }
                    .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("LOCIQ")
                    .accessibilityIdentifier("app.brand")

                    Spacer(minLength: 28)

                    if !isWaitingForInitialData && snapshot.hasDemographicData {
                        Button(action: onShowDetails) {
                            Image(systemName: iconName)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .accessibilityLabel(actionLabel)
                    }
                }

                ProgressLine(progress: snapshot.confidence, isLoading: isLoading)
            }
            .frame(maxWidth: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demographics.summary")
    }
}

private struct FadingContentPanel: View {
    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(snapshot: snapshot)
                    .transition(.opacity)
            } else {
                MetricContent(metrics: snapshot.metrics)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .animation(.easeInOut(duration: 0.58), value: isShowingDetails)
    }
}

private struct MetricContent: View {
    let metrics: [DemographicMetric]

    var body: some View {
        VStack(alignment: .trailing, spacing: 22) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct DetailContent: View {
    let snapshot: DemographicSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 18) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ZipBoundaryPreview: View {
    let boundary: GeoJSONFeatureCollection
    let coordinate: CLLocationCoordinate2D?
    let traceToken: Int
    @State private var traceProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BoundaryPreviewShape(boundary: boundary)
                    .trim(from: 0, to: traceProgress)
                    .stroke(
                        Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
                    )

                if let coordinate,
                   let locationPoint = GeoJSONBoundaryPathBuilder.point(
                    for: coordinate,
                    in: CGRect(origin: .zero, size: proxy.size),
                    fittingTo: boundary
                   ) {
                    PulsingLocationDot()
                        .position(locationPoint)
                }
            }
            .background(Color.clear)
        }
        .onAppear {
            traceBoundary()
        }
        .onChange(of: traceToken) { _ in
            traceBoundary()
        }
        .accessibilityHidden(true)
    }

    private func traceBoundary() {
        withAnimation(.none) {
            traceProgress = 0
        }
        withAnimation(.easeInOut(duration: 2.2).delay(0.18)) {
            traceProgress = 1
        }
    }
}

private struct PulsingLocationDot: View {
    @State private var isPulsing = false
    private let locationTint = Color(red: 1.0, green: 0.82, blue: 0.22)

    var body: some View {
        ZStack {
            Circle()
                .stroke(locationTint.opacity(isPulsing ? 0.0 : 0.46), lineWidth: 0.8)
                .frame(width: 12, height: 12)
                .scaleEffect(isPulsing ? 2.25 : 0.55)

            Circle()
                .fill(locationTint.opacity(0.9))
                .frame(width: 3.4, height: 3.4)
        }
        .frame(width: 30, height: 30)
        .onAppear {
            withAnimation(.easeOut(duration: 1.75).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

private struct BoundaryCityConnectorLine: View {
    let start: CGPoint
    let end: CGPoint
    let traceToken: Int
    @State private var progress: CGFloat = 0

    var body: some View {
        BoundaryCityConnectorShape(start: start, end: end)
            .trim(from: 0, to: progress)
            .stroke(
                Color.white.opacity(0.16),
                style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
            )
            .onAppear {
                traceConnector()
            }
            .onChange(of: traceToken) { _ in
                traceConnector()
            }
    }

    private func traceConnector() {
        withAnimation(.none) {
            progress = 0
        }
        withAnimation(.easeOut(duration: 1.05).delay(2.55)) {
            progress = 1
        }
    }
}

private struct BoundaryCityConnectorShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct BoundaryCityConnectionAnchors: Equatable {
    var boundary: Anchor<CGRect>?
    var city: Anchor<CGRect>?
}

private struct BoundaryCityConnectionPreferenceKey: PreferenceKey {
    static var defaultValue = BoundaryCityConnectionAnchors()

    static func reduce(value: inout BoundaryCityConnectionAnchors, nextValue: () -> BoundaryCityConnectionAnchors) {
        let next = nextValue()
        value.boundary = next.boundary ?? value.boundary
        value.city = next.city ?? value.city
    }
}

private struct BoundaryPreviewShape: Shape {
    let boundary: GeoJSONFeatureCollection
    var fittingBoundary: GeoJSONFeatureCollection?

    func path(in rect: CGRect) -> Path {
        guard
            let boundaryPath = GeoJSONBoundaryPathBuilder.path(
                for: boundary,
                in: rect,
                fittingTo: fittingBoundary
            )
        else {
            return Path()
        }

        return boundaryPath
    }
}

private struct DetailSectionView: View {
    let section: DemographicDetailSection

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(section.title)
                .font(.system(size: 13, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))

            VStack(alignment: .trailing, spacing: 7) {
                ForEach(section.rows) { row in
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            DetailRowLabel(label: row.label)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                                .padding(.leading, 2)
                                .layoutPriority(1)

                            Spacer(minLength: 10)

                            Text(row.value)
                                .font(.system(size: 17, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                        }
                        .frame(maxWidth: .infinity)
                        .monospacedDigit()

                        if let progress = row.progress {
                            ProgressLine(progress: progress)
                                .opacity(0.78)
                                .frame(maxWidth: 220)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailRowLabel: View {
    let label: String

    var body: some View {
        labelText
            .foregroundStyle(.white.opacity(0.46))
    }

    private var labelText: Text {
        switch label {
        case "UNDER 18":
            return word("UNDER") + space + number("18")
        case "18 TO 34":
            return number("18") + space + word("TO") + space + number("34")
        case "35 TO 64":
            return number("35") + space + word("TO") + space + number("64")
        case "65 PLUS":
            return number("65") + space + word("PLUS")
        default:
            return Text(label)
                .font(.system(size: 12, weight: .regular, design: .rounded))
        }
    }

    private var space: Text {
        Text(" ")
            .font(.system(size: 12, weight: .regular, design: .rounded))
    }

    private func word(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 9.5, weight: .regular, design: .rounded))
    }

    private func number(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 12.5, weight: .regular, design: .rounded))
    }
}

private struct ProgressLine: View {
    let progress: Double
    var isLoading = false
    @State private var loadingOffset: CGFloat = -0.28

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 1)

                if isLoading {
                    Rectangle()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: max(44, geometry.size.width * 0.24), height: 1)
                        .offset(x: geometry.size.width * loadingOffset)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 1)
                }
            }
            .clipped()
        }
        .frame(height: 1)
        .task(id: isLoading) {
            guard isLoading else {
                loadingOffset = -0.28
                return
            }

            while !Task.isCancelled {
                loadingOffset = -0.28
                try? await Task.sleep(nanoseconds: 35_000_000)
                withAnimation(.linear(duration: 0.82)) {
                    loadingOffset = 1.04
                }
                try? await Task.sleep(nanoseconds: 860_000_000)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension Color {
    static let lociqInk = Color(red: 0.075, green: 0.075, blue: 0.072)
}

#Preview {
    ContentView()
}
