//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import Combine
import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationAccess = LocationAccessModel()
    @StateObject private var locationProfile = ACSLocationProfileModel()
    @State private var isShowingDetails = false
    @State private var isLoadingContent = false

    private let debugLocationOverride = DebugLocationOverride.current

    private var canDisplayLocationProfile: Bool {
        locationAccess.canUseLocation || debugLocationOverride != nil
    }

    private var activeCoordinate: CLLocationCoordinate2D? {
        debugLocationOverride?.coordinate ?? locationAccess.coordinate
    }

    private var shouldShowLocationPlaceholder: Bool {
        debugLocationOverride == nil && locationAccess.isUnavailable
    }

    private var displaySnapshot: DemographicSnapshot {
        guard !shouldShowLocationPlaceholder else { return .placeholder }
        return locationProfile.snapshot ?? .loading
    }

    private var canShowBoundary: Bool {
        !isWaitingForInitialData
            && !shouldShowLocationPlaceholder
            && locationProfile.boundary != nil
    }

    private var isWaitingForInitialData: Bool {
        !shouldShowLocationPlaceholder
            && locationProfile.boundary == nil
            && (locationProfile.snapshot == nil || locationProfile.isLoading)
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
                        traceToken: locationProfile.traceToken + (canDisplayLocationProfile ? 1 : 0)
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
                    isLoading: isLoadingContent || locationProfile.isLoading || isWaitingForInitialData,
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
                            traceToken: locationProfile.traceToken + (canDisplayLocationProfile ? 1 : 0)
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
            if let debugLocationOverride {
                locationProfile.load(for: debugLocationOverride.coordinate)
            } else {
                locationAccess.requestAccessIfNeeded()
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, debugLocationOverride == nil else { return }
            locationAccess.requestAccessIfNeeded()
        }
        .onReceive(locationAccess.$coordinate.compactMap { $0 }) { coordinate in
            locationProfile.load(for: coordinate)
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

private final class LocationAccessModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    var canUseLocation: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .notDetermined, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    var isUnavailable: Bool {
        switch authorizationStatus {
        case .denied, .restricted:
            return true
        case .authorizedAlways, .authorizedWhenInUse, .notDetermined:
            return false
        @unknown default:
            return true
        }
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAccessIfNeeded() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if canUseLocation {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard canUseLocation else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        authorizationStatus = manager.authorizationStatus
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

@MainActor
private final class ACSLocationProfileModel: ObservableObject {
    @Published private(set) var snapshot: DemographicSnapshot?
    @Published private(set) var boundary: GeoJSONFeatureCollection?
    @Published private(set) var traceToken = 0
    @Published private(set) var isLoading = false

    private let censusService: CensusZipDemographicsService
    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private let hasCensusAPIKey: Bool
    private var lastCoordinateKey: String?

    init() {
        let httpClient = CensusHTTPClient(session: .shared)
        let censusAPIKey = AppConfig.censusAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        censusService = CensusZipDemographicsService(censusApiKey: censusAPIKey)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
        hasCensusAPIKey = !censusAPIKey.isEmpty
    }

    func load(for coordinate: CLLocationCoordinate2D) {
        let coordinateKey = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        guard coordinateKey != lastCoordinateKey else { return }
        lastCoordinateKey = coordinateKey

        isLoading = true
        snapshot = .loading
        boundary = nil

        Task {
            guard hasCensusAPIKey else {
                await loadLocationShell(for: coordinate, status: .censusKeyMissing)
                isLoading = false
                return
            }

            do {
                let profile = try await censusService.fetchPlaceProfile(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                guard let cityDemographics = profile.scaleDemographics.place else {
                    var fallbackBoundary = profile.boundaries.city
                    if fallbackBoundary == nil {
                        fallbackBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.zipBundle.place)
                    }
                    snapshot = DemographicSnapshot.status(
                        for: .acsUnavailable,
                        market: DemographicValueFormatter.title(from: profile).uppercased()
                    )
                    boundary = fallbackBoundary
                    traceToken += 1
                    isLoading = false
                    return
                }

                var cityBoundary = profile.boundaries.city
                if cityBoundary == nil {
                    cityBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.zipBundle.place)
                }

                snapshot = DemographicSnapshot(profile: profile, demographics: cityDemographics)
                boundary = cityBoundary
                traceToken += 1
            } catch {
                await loadLocationShell(for: coordinate, status: .acsUnavailable)
            }
            isLoading = false
        }
    }

    private func loadLocationShell(for coordinate: CLLocationCoordinate2D, status: DemographicSnapshot.LocationStatus) async {
        do {
            let geography = try await geocoderClient.fetchGeographiesFromCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            let areaTitle = DemographicValueFormatter.cityTitle(from: geography) ?? "CITY UNAVAILABLE"
            let resolvedBoundary = await boundaryClient.fetchPlaceBoundary(place: geography.place)

            snapshot = DemographicSnapshot.status(for: status, market: areaTitle.uppercased())
            if let resolvedBoundary {
                boundary = resolvedBoundary
            } else {
                boundary = nil
            }
            traceToken += 1
        } catch {
            boundary = nil
            snapshot = DemographicSnapshot.status(for: status, market: status.fallbackMarket)
            traceToken += 1
        }
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

private enum GeoJSONBoundaryPathBuilder {
    nonisolated static func path(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> Path? {
        guard let projectedBoundary = projectedBoundary(for: boundary, in: rect, fittingTo: fittingBoundary) else {
            return nil
        }

        var path = Path()
        for ring in projectedBoundary.rings {
            var didMove = false
            for point in ring {
                if didMove {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    didMove = true
                }
            }
            path.closeSubpath()
        }

        return path
    }

    nonisolated static func center(for boundary: GeoJSONFeatureCollection?, fallbackRect: CGRect) -> CGPoint {
        guard
            let boundary,
            let projectedBoundary = projectedBoundary(
                for: boundary,
                in: CGRect(origin: .zero, size: fallbackRect.size)
            )
        else {
            return CGPoint(x: fallbackRect.width / 2, y: fallbackRect.height / 2)
        }

        return CGPoint(x: projectedBoundary.bounds.midX, y: projectedBoundary.bounds.midY)
    }

    nonisolated static func point(
        for coordinate: CLLocationCoordinate2D,
        in rect: CGRect,
        fittingTo boundary: GeoJSONFeatureCollection
    ) -> CGPoint? {
        guard
            let projectedBoundary = projectedBoundary(for: boundary, in: rect),
            let projectedPoint = googleMapsWorldPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
        else {
            return nil
        }

        let x = projectedBoundary.xOffset + (projectedPoint.x - projectedBoundary.minProjectedX) * projectedBoundary.scale
        let y = projectedBoundary.yOffset + (projectedPoint.y - projectedBoundary.minProjectedY) * projectedBoundary.scale
        let point = CGPoint(x: x, y: y)
        return rect.insetBy(dx: -2, dy: -2).contains(point) ? point : nil
    }

    nonisolated private static func projectedBoundary(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> ProjectedBoundary? {
        let rings = boundary.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }

        guard !rings.isEmpty else { return nil }

        let fittingRings = fittingBoundary?.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }
        let boundsRings = fittingRings?.isEmpty == false ? fittingRings ?? rings : rings

        let points = rings.flatMap { ring in
            ring.compactMap { coordinate -> CGPoint? in
                guard coordinate.count >= 2 else { return nil }
                return googleMapsWorldPoint(longitude: coordinate[0], latitude: coordinate[1])
            }
        }
        let boundsPoints = boundsRings.flatMap { ring in
            ring.compactMap { coordinate -> CGPoint? in
                guard coordinate.count >= 2 else { return nil }
                return googleMapsWorldPoint(longitude: coordinate[0], latitude: coordinate[1])
            }
        }

        guard
            !points.isEmpty,
            let minProjectedX = boundsPoints.map(\.x).min(),
            let maxProjectedX = boundsPoints.map(\.x).max(),
            let minProjectedY = boundsPoints.map(\.y).min(),
            let maxProjectedY = boundsPoints.map(\.y).max(),
            maxProjectedX > minProjectedX,
            maxProjectedY > minProjectedY
        else {
            return nil
        }

        let projectedWidth = maxProjectedX - minProjectedX
        let projectedHeight = maxProjectedY - minProjectedY
        let scale = min(rect.width / projectedWidth, rect.height / projectedHeight) * 0.92
        let drawingWidth = projectedWidth * scale
        let drawingHeight = projectedHeight * scale
        let xOffset = rect.midX - drawingWidth / 2
        let yOffset = rect.midY - drawingHeight / 2

        var projectedRings: [[CGPoint]] = []
        for ring in rings {
            var projectedRing: [CGPoint] = []
            for coordinate in ring where coordinate.count >= 2 {
                guard let projectedPoint = googleMapsWorldPoint(longitude: coordinate[0], latitude: coordinate[1]) else {
                    continue
                }
                let x = xOffset + (projectedPoint.x - minProjectedX) * scale
                let y = yOffset + (projectedPoint.y - minProjectedY) * scale
                let point = CGPoint(x: x, y: y)
                projectedRing.append(point)
            }
            if projectedRing.count > 2 {
                projectedRings.append(projectedRing)
            }
        }

        guard !projectedRings.isEmpty else { return nil }
        let allProjectedPoints = projectedRings.flatMap { $0 }
        guard
            let minX = allProjectedPoints.map(\.x).min(),
            let maxX = allProjectedPoints.map(\.x).max(),
            let minY = allProjectedPoints.map(\.y).min(),
            let maxY = allProjectedPoints.map(\.y).max()
        else {
            return nil
        }

        return ProjectedBoundary(
            rings: projectedRings,
            bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
            minProjectedX: minProjectedX,
            minProjectedY: minProjectedY,
            xOffset: xOffset,
            yOffset: yOffset,
            scale: scale
        )
    }

    private struct ProjectedBoundary {
        let rings: [[CGPoint]]
        let bounds: CGRect
        let minProjectedX: CGFloat
        let minProjectedY: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat
        let scale: CGFloat
    }

    nonisolated private static func googleMapsWorldPoint(longitude: Double, latitude: Double) -> CGPoint? {
        guard longitude.isFinite, latitude.isFinite else { return nil }
        let clampedLatitude = min(max(latitude, -85.05112878), 85.05112878)
        let latitudeRadians = clampedLatitude * .pi / 180
        let sinLatitude = sin(latitudeRadians)
        return CGPoint(
            x: (longitude + 180) / 360,
            y: 0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * .pi)
        )
    }

    nonisolated private static func exteriorRings(from geometry: GeoJSONGeometry) -> [[[Double]]] {
        switch geometry {
        case .polygon(let rings):
            return rings.first.map { [$0] } ?? []
        case .multiPolygon(let polygons):
            return polygons.compactMap(\.first)
        case .other:
            return []
        }
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

private struct DemographicSnapshot {
    enum LocationStatus {
        case censusKeyMissing
        case acsUnavailable

        var fallbackMarket: String {
            switch self {
            case .censusKeyMissing:
                return "CENSUS KEY"
            case .acsUnavailable:
                return "ACS"
            }
        }
    }

    let market: String
    let dateLabel: String
    let cadence: String
    let mode: String
    let confidence: Double
    let hasDemographicData: Bool
    let metrics: [DemographicMetric]
    let detailSections: [DemographicDetailSection]

    static let placeholder = DemographicSnapshot(
        market: "LOCATION",
        dateLabel: "ENABLE ACCESS",
        cadence: "DEMOGRAPHICS PAUSED",
        mode: "LOCATION",
        confidence: 0,
        hasDemographicData: false,
        metrics: [
            DemographicMetric(
                title: "ACCESS",
                primaryValue: "--",
                detail: "ENABLE LOCATION"
            )
        ],
        detailSections: []
    )

    static let loading = DemographicSnapshot.status(
        market: "LOCATING",
        dateLabel: "ACS",
        cadence: "READING AREA",
        mode: "LOADING"
    )

    static func status(for status: LocationStatus, market: String) -> DemographicSnapshot {
        switch status {
        case .censusKeyMissing:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "CENSUS KEY",
                cadence: "ADD API KEY",
                mode: "NO KEY"
            )
        case .acsUnavailable:
            return DemographicSnapshot.status(
                market: market,
                dateLabel: "ACS",
                cadence: "TRY AGAIN LATER",
                mode: "OFFLINE"
            )
        }
    }

    private static func status(
        market: String,
        dateLabel: String,
        cadence: String,
        mode: String
    ) -> DemographicSnapshot {
        DemographicSnapshot(
            market: market,
            dateLabel: dateLabel,
            cadence: cadence,
            mode: mode,
            confidence: 0,
            hasDemographicData: false,
            metrics: [
                DemographicMetric(title: "CITY PROFILE", primaryValue: "--", detail: cadence)
            ],
            detailSections: []
        )
    }
}

private extension DemographicSnapshot {
    init(profile: ResolvedPlaceProfile, demographics: Demographics) {
        let households = DemographicValueFormatter.households(from: demographics)
        let ownerPct = DemographicValueFormatter.percent(demographics.ownerOccupiedPct)

        self.init(
            market: DemographicValueFormatter.title(from: profile).uppercased(),
            dateLabel: "",
            cadence: "",
            mode: "DEMOGRAPHICS",
            confidence: 0.84,
            hasDemographicData: true,
            metrics: [
                DemographicMetric(
                    title: "POPULATION",
                    primaryValue: DemographicValueFormatter.number(demographics.population),
                    detail: "MEDIAN AGE \(DemographicValueFormatter.decimal(demographics.medianAge))"
                ),
                DemographicMetric(
                    title: "HOUSEHOLDS",
                    primaryValue: DemographicValueFormatter.number(households),
                    detail: "OCCUPIED HOMES"
                ),
                DemographicMetric(
                    title: "INCOME",
                    primaryValue: DemographicValueFormatter.currency(demographics.medianHouseholdIncome),
                    detail: "MEDIAN HOUSEHOLD"
                ),
                DemographicMetric(
                    title: "RENTERS",
                    primaryValue: DemographicValueFormatter.percent(demographics.renterOccupiedPct),
                    detail: "\(ownerPct) OWNER OCCUPIED"
                ),
                DemographicMetric(
                    title: "EDUCATION",
                    primaryValue: DemographicValueFormatter.percent(demographics.bachelorsOrHigherPct),
                    detail: "BACHELOR'S OR HIGHER"
                )
            ],
            detailSections: [
                DemographicDetailSection(
                    title: "AGE",
                    rows: [
                        DemographicDetailRow(label: "UNDER 18", value: DemographicValueFormatter.percent(demographics.under18Pct)),
                        DemographicDetailRow(label: "18 TO 34", value: DemographicValueFormatter.percent(demographics.age18To34Pct)),
                        DemographicDetailRow(label: "35 TO 64", value: DemographicValueFormatter.percent(demographics.age35To64Pct)),
                        DemographicDetailRow(label: "65 PLUS", value: DemographicValueFormatter.percent(demographics.age65PlusPct))
                    ]
                ),
                DemographicDetailSection(
                    title: "HOUSING",
                    rows: [
                        DemographicDetailRow(label: "MEDIAN RENT", value: DemographicValueFormatter.currency(demographics.medianGrossRent)),
                        DemographicDetailRow(label: "MEDIAN VALUE", value: DemographicValueFormatter.currency(demographics.medianHomeValue)),
                        DemographicDetailRow(label: "VACANCY", value: DemographicValueFormatter.percent(demographics.vacancyRatePct))
                    ]
                ),
                DemographicDetailSection(
                    title: "MOBILITY",
                    rows: [
                        DemographicDetailRow(label: "TRANSIT", value: DemographicValueFormatter.percent(demographics.transitCommutersPct)),
                        DemographicDetailRow(label: "REMOTE WORK", value: DemographicValueFormatter.percent(demographics.workersWfhPct)),
                        DemographicDetailRow(label: "AVG COMMUTE", value: DemographicValueFormatter.minutes(demographics.averageCommuteMinutes))
                    ]
                )
            ]
        )
    }
}

private enum DemographicValueFormatter {
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func title(from profile: ResolvedPlaceProfile) -> String {
        if let placeName = profile.zipBundle.place?.name, !placeName.isEmpty {
            return cleanGeographyName(placeName)
        }

        return cleanGeographyName(profile.zipBundle.demographics.name)
    }

    static func title(from geography: CensusGeographiesBundle) -> String {
        if let placeName = geography.place?.name, !placeName.isEmpty {
            return cleanGeographyName(placeName)
        }
        if let countyName = geography.county?.name, !countyName.isEmpty {
            return cleanGeographyName(countyName)
        }
        return "ZIP \(geography.zcta)"
    }

    static func cityTitle(from geography: CensusGeographiesBundle) -> String? {
        guard let placeName = geography.place?.name, !placeName.isEmpty else {
            return nil
        }

        return cleanGeographyName(placeName)
    }

    static func households(from demographics: Demographics) -> Int? {
        if let owner = demographics.ownerOccupied, let renter = demographics.renterOccupied {
            return owner + renter
        }
        return demographics.housingUnits
    }

    static func number(_ value: Int?) -> String {
        guard let value else { return "--" }
        return integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func currency(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "--" }
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    static func decimal(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return String(format: "%.1f", value)
    }

    static func percent(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    static func minutes(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded())) MIN"
    }

    private static func cleanGeographyName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " city", with: "")
            .replacingOccurrences(of: " town", with: "")
            .replacingOccurrences(of: " CDP", with: "")
            .replacingOccurrences(of: "ZCTA5 ", with: "ZIP ")
            .replacingOccurrences(of: ", United States", with: "")
    }
}

private struct DemographicMetric: Identifiable {
    let id = UUID()
    let title: String
    let primaryValue: String
    let detail: String
}

private struct DemographicDetailSection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [DemographicDetailRow]
}

private struct DemographicDetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let progress: Double?

    init(label: String, value: String, progress: Double? = nil) {
        self.label = label
        self.value = value
        self.progress = progress
    }
}

private extension Color {
    static let lociqInk = Color(red: 0.075, green: 0.075, blue: 0.072)
}

#Preview {
    ContentView()
}
