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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            let layout = MinimalLayout(geometry: geometry)

            ZStack(alignment: .topTrailing) {
                MinimalBackground()

                if canShowBoundary, let boundary = locationProfile.boundary {
                    ZipBoundaryPreview(
                        boundary: boundary,
                        coordinate: activeCoordinate,
                        horizontalAccuracy: locationProfile.horizontalAccuracy,
                        traceToken: locationProfile.traceToken,
                        reduceMotion: reduceMotion
                    )
                        .frame(
                            width: layout.boundarySize.width,
                            height: layout.boundarySize.height
                        )
                        .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                            BoundaryCityConnectionAnchors(boundary: $0)
                        }
                        .padding(.top, layout.boundaryTop)
                        .padding(.leading, layout.boundaryLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityLabel("City boundary")
                }

                if !isWaitingForInitialData {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .trailing, spacing: 34) {
                            HeaderBlock(snapshot: displaySnapshot, layout: layout)

                            FadingContentPanel(
                                snapshot: displaySnapshot,
                                isShowingDetails: isShowingDetails,
                                layout: layout,
                                reduceMotion: reduceMotion
                            )
                            .frame(
                                maxWidth: isShowingDetails ? layout.detailContentWidth : .infinity,
                                alignment: .trailing
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(
                        maxWidth: layout.contentWidth,
                        maxHeight: layout.detailHeight,
                        alignment: .topTrailing
                    )
                    .padding(.top, layout.topInset)
                    .padding(.trailing, layout.trailingInset)
                }

                BottomIdentity(
                    snapshot: displaySnapshot,
                    isShowingDetails: isShowingDetails,
                    isLoading: isLoadingContent || locationProfile.isLoading,
                    isWaitingForInitialData: isWaitingForInitialData,
                    canRetry: locationProfile.canRetry,
                    needsLocationPermission: locationProfile.needsLocationPermissionPrompt,
                    brandFontSize: layout.brandFontSize,
                    reduceMotion: reduceMotion
                ) {
                    handleBottomAction()
                }
                    .padding(.horizontal, layout.horizontalInset)
                    .padding(.bottom, layout.bottomInset)
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
                            traceToken: locationProfile.traceToken,
                            reduceMotion: reduceMotion
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

        Haptics.selectionChanged()

        withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
            isLoadingContent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LociqMotion.phaseDelay(reduceMotion: reduceMotion)) {
            withAnimation(LociqMotion.content(reduceMotion: reduceMotion)) {
                isShowingDetails.toggle()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LociqMotion.contentCycleDuration(reduceMotion: reduceMotion)) {
            withAnimation(LociqMotion.settle(reduceMotion: reduceMotion)) {
                isLoadingContent = false
            }
        }
    }

    private func handleBottomAction() {
        if displaySnapshot.hasDemographicData {
            cycleContent()
        } else if locationProfile.needsLocationPermissionPrompt {
            locationProfile.requestLocationAccess()
        } else if locationProfile.canRetry {
            Haptics.selectionChanged()
            locationProfile.retry()
        }
    }
}

private struct MinimalLayout {
    let isCompactWidth: Bool
    let isShortHeight: Bool
    let topInset: CGFloat
    let bottomInset: CGFloat
    let bottomReserve: CGFloat
    let detailHeight: CGFloat
    let contentWidth: CGFloat
    let detailContentWidth: CGFloat
    let trailingInset: CGFloat
    let horizontalInset: CGFloat
    let boundarySize: CGSize
    let boundaryTop: CGFloat
    let boundaryLeading: CGFloat
    let cityFontSize: CGFloat
    let metricTitleSize: CGFloat
    let metricValueSize: CGFloat
    let metricDetailSize: CGFloat
    let brandFontSize: CGFloat
    let detailValueSize: CGFloat
    let detailLabelWordSize: CGFloat
    let detailLabelNumberSize: CGFloat

    init(geometry: GeometryProxy) {
        let width = geometry.size.width
        let height = geometry.size.height
        isCompactWidth = width < 380
        isShortHeight = height < 700
        topInset = max(isShortHeight ? 44 : 54, geometry.safeAreaInsets.top + (isShortHeight ? 24 : 34))
        bottomInset = max(isShortHeight ? 22 : 30, geometry.safeAreaInsets.bottom + (isShortHeight ? 14 : 20))
        bottomReserve = height < 520 ? 168 : (isShortHeight ? 174 : 190)
        detailHeight = max(112, height - topInset - bottomReserve)
        trailingInset = isCompactWidth ? 22 : 28
        horizontalInset = isCompactWidth ? 20 : 24
        contentWidth = min(width * (isCompactWidth ? 0.68 : 0.64), isCompactWidth ? 292 : 340)
        detailContentWidth = min(width * (isCompactWidth ? 0.55 : 0.50), isCompactWidth ? 214 : 246)
        boundarySize = CGSize(
            width: min(max(width * (isCompactWidth ? 0.25 : 0.28), isCompactWidth ? 82 : 96), isCompactWidth ? 118 : 142),
            height: min(max(height * (isShortHeight ? 0.16 : 0.19), isShortHeight ? 92 : 112), isShortHeight ? 132 : 158)
        )
        boundaryTop = topInset + (isShortHeight ? 78 : 96)
        boundaryLeading = isCompactWidth ? 24 : 30
        cityFontSize = isCompactWidth ? 24 : 28
        metricTitleSize = isCompactWidth ? 13 : 14
        metricValueSize = isCompactWidth ? 17 : 18
        metricDetailSize = isCompactWidth ? 11.5 : 12
        brandFontSize = isCompactWidth ? 22 : 24
        detailValueSize = isCompactWidth ? 16 : 17
        detailLabelWordSize = isCompactWidth ? 9 : 9.5
        detailLabelNumberSize = isCompactWidth ? 12 : 12.5
    }
}

private enum LociqMotion {
    static let quickDuration = 0.18
    static let contentDuration = 0.58
    static let settleDuration = 0.32
    static let boundaryTraceDuration = 2.2
    static let boundaryTraceDelay = 0.18
    static let connectorDuration = 1.05
    static let connectorDelay = 2.55
    static let pulseDuration = 1.75
    static let loadingSweepDuration = 0.82
    static let loadingSweepPauseNanoseconds: UInt64 = 860_000_000
    static let phaseDelay = 0.22
    static let contentCycleDuration = 1.05

    static var quick: Animation { .easeInOut(duration: quickDuration) }
    static var content: Animation { .easeInOut(duration: contentDuration) }
    static var settle: Animation { .easeInOut(duration: settleDuration) }
    static var boundaryTrace: Animation { .easeInOut(duration: boundaryTraceDuration).delay(boundaryTraceDelay) }
    static var connector: Animation { .easeOut(duration: connectorDuration).delay(connectorDelay) }
    static var pulse: Animation { .easeOut(duration: pulseDuration).repeatForever(autoreverses: false) }
    static var loadingSweep: Animation { .linear(duration: loadingSweepDuration) }

    static func quick(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : quick
    }

    static func content(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : content
    }

    static func settle(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : settle
    }

    static func boundaryTrace(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : boundaryTrace
    }

    static func connector(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : connector
    }

    static func pulse(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : pulse
    }

    static func loadingSweep(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : loadingSweep
    }

    static func phaseDelay(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.05 : phaseDelay
    }

    static func contentCycleDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.18 : contentCycleDuration
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
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(snapshot.market)
                .font(.system(size: layout.cityFontSize, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .allowsTightening(true)
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
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(metric.title)
                .font(.system(size: layout.metricTitleSize, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text(metric.primaryValue)
                .font(.system(size: layout.metricValueSize, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)

            Text(metric.detail)
                .font(.system(size: layout.metricDetailSize, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
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
    let canRetry: Bool
    let needsLocationPermission: Bool
    var brandFontSize: CGFloat = 24
    var reduceMotion = false
    let onShowDetails: () -> Void

    private var iconName: String {
        if !snapshot.hasDemographicData {
            return needsLocationPermission ? "location" : "arrow.clockwise"
        }
        return isShowingDetails ? "house" : "list.bullet.rectangle"
    }

    private var actionLabel: String {
        if !snapshot.hasDemographicData {
            return needsLocationPermission ? "Enable location access" : "Retry loading data"
        }
        return isShowingDetails ? "Show home view" : "Show data view"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("LOC")
                        Text("IQ")
                    }
                    .font(.system(size: brandFontSize, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("LOCIQ")
                    .accessibilityIdentifier("app.brand")

                    Spacer(minLength: 28)

                    if !isWaitingForInitialData && (snapshot.hasDemographicData || canRetry) {
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
        .accessibilityIdentifier("demographics.summary")
    }
}

private struct FadingContentPanel: View {
    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool
    let layout: MinimalLayout
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(snapshot: snapshot, layout: layout)
                    .opacity(0.9)
                    .offset(y: reduceMotion ? 0 : (layout.isShortHeight ? -2 : 2))
                    .transition(contentTransition)
            } else {
                MetricContent(metrics: snapshot.metrics, layout: layout)
                    .transition(contentTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .animation(LociqMotion.content(reduceMotion: reduceMotion), value: isShowingDetails)
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity
        )
    }
}

private struct MetricContent: View {
    let metrics: [DemographicMetric]
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 18 : 22) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct DetailContent: View {
    let snapshot: DemographicSnapshot
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 14 : 18) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ZipBoundaryPreview: View {
    let boundary: GeoJSONFeatureCollection
    let coordinate: CLLocationCoordinate2D?
    let horizontalAccuracy: CLLocationAccuracy?
    let traceToken: Int
    let reduceMotion: Bool
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
                    let dotStyle = LocationDotStyle(accuracy: horizontalAccuracy)
                    if dotStyle.isVisible {
                        PulsingLocationDot(style: dotStyle, reduceMotion: reduceMotion)
                            .position(locationPoint)
                    }
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
            traceProgress = reduceMotion ? 1 : 0
        }

        guard let animation = LociqMotion.boundaryTrace(reduceMotion: reduceMotion) else { return }
        withAnimation(animation) {
            traceProgress = 1
        }
    }
}

private struct LocationDotStyle {
    let tintOpacity: Double
    let ringOpacity: Double
    let coreDiameter: CGFloat
    let ringDiameter: CGFloat
    let pulseScale: CGFloat
    let isVisible: Bool

    init(accuracy: CLLocationAccuracy?) {
        guard let accuracy, accuracy >= 0 else {
            tintOpacity = 0.86
            ringOpacity = 0.38
            coreDiameter = 3.2
            ringDiameter = 12
            pulseScale = 2.1
            isVisible = true
            return
        }

        if accuracy <= 100 {
            tintOpacity = 0.95
            ringOpacity = 0.52
            coreDiameter = 3.8
            ringDiameter = 10
            pulseScale = 1.85
            isVisible = true
        } else if accuracy <= 1_000 {
            tintOpacity = 0.82
            ringOpacity = 0.34
            coreDiameter = 3.2
            ringDiameter = 13
            pulseScale = 2.35
            isVisible = true
        } else if accuracy <= 5_000 {
            tintOpacity = 0.64
            ringOpacity = 0.22
            coreDiameter = 2.8
            ringDiameter = 15
            pulseScale = 2.75
            isVisible = true
        } else {
            tintOpacity = 0.64
            ringOpacity = 0.22
            coreDiameter = 2.8
            ringDiameter = 15
            pulseScale = 2.75
            isVisible = false
        }
    }
}

private struct PulsingLocationDot: View {
    let style: LocationDotStyle
    let reduceMotion: Bool
    @State private var isPulsing = false
    private let locationTint = Color(red: 1.0, green: 0.82, blue: 0.22)

    var body: some View {
        ZStack {
            Circle()
                .stroke(locationTint.opacity(isPulsing ? 0.0 : style.ringOpacity), lineWidth: 0.8)
                .frame(width: style.ringDiameter, height: style.ringDiameter)
                .scaleEffect(isPulsing ? style.pulseScale : 0.55)

            Circle()
                .fill(locationTint.opacity(style.tintOpacity))
                .frame(width: style.coreDiameter, height: style.coreDiameter)
        }
        .frame(width: 30, height: 30)
        .onAppear {
            guard let animation = LociqMotion.pulse(reduceMotion: reduceMotion) else { return }
            withAnimation(animation) {
                isPulsing.toggle()
            }
        }
    }
}

private struct BoundaryCityConnectorLine: View {
    let start: CGPoint
    let end: CGPoint
    let traceToken: Int
    let reduceMotion: Bool
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
            progress = reduceMotion ? 1 : 0
        }

        guard let animation = LociqMotion.connector(reduceMotion: reduceMotion) else { return }
        withAnimation(animation) {
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
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(section.title)
                .font(.system(size: 13, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))

            VStack(alignment: .trailing, spacing: 7) {
                ForEach(section.rows) { row in
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            DetailRowLabel(label: row.label, layout: layout)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                                .padding(.leading, 2)
                                .layoutPriority(1)

                            Spacer(minLength: 10)

                            Text(row.value)
                                .font(.system(size: layout.detailValueSize, weight: .light, design: .rounded))
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
    let layout: MinimalLayout

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
                .font(.system(size: layout.detailLabelNumberSize - 0.5, weight: .regular, design: .rounded))
        }
    }

    private var space: Text {
        Text(" ")
            .font(.system(size: layout.detailLabelNumberSize - 0.5, weight: .regular, design: .rounded))
    }

    private func word(_ text: String) -> Text {
        Text(text)
            .font(.system(size: layout.detailLabelWordSize, weight: .regular, design: .rounded))
    }

    private func number(_ text: String) -> Text {
        Text(text)
            .font(.system(size: layout.detailLabelNumberSize, weight: .regular, design: .rounded))
    }
}

private struct ProgressLine: View {
    let progress: Double
    var isLoading = false
    var reduceMotion = false
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
                        .frame(
                            width: reduceMotion ? geometry.size.width : max(44, geometry.size.width * 0.24),
                            height: 1
                        )
                        .offset(x: reduceMotion ? 0 : geometry.size.width * loadingOffset)
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
            guard !reduceMotion else {
                loadingOffset = 0
                return
            }

            while !Task.isCancelled {
                loadingOffset = -0.28
                try? await Task.sleep(nanoseconds: 35_000_000)
                guard let animation = LociqMotion.loadingSweep(reduceMotion: reduceMotion) else { return }
                withAnimation(animation) {
                    loadingOffset = 1.04
                }
                try? await Task.sleep(nanoseconds: LociqMotion.loadingSweepPauseNanoseconds)
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
