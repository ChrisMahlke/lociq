//
//  BoundaryPreview.swift
//  Lociq
//
//  Draws the city boundary, approximate location pulse, and city connector line.
//

import CoreLocation
import SwiftUI

struct CityBoundaryPreview: View {
    let boundary: GeoJSONFeatureCollection
    let coordinate: CLLocationCoordinate2D?
    let horizontalAccuracy: CLLocationAccuracy?
    let traceToken: Int
    let reduceMotion: Bool
    @State private var traceProgress: CGFloat = 0
    @State private var showsLocationDot = false
    @State private var locationDotTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            if let projection = GeoJSONBoundaryPathBuilder.projection(for: boundary, in: rect) {
                ZStack {
                    BoundaryPreviewShape(projection: projection)
                        .trim(from: 0, to: traceProgress)
                        .stroke(
                            Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
                        )

                    if showsLocationDot, let coordinate, let locationPoint = projection.point(for: coordinate) {
                        let dotStyle = LocationDotStyle(accuracy: horizontalAccuracy)
                        if dotStyle.isVisible {
                            PulsingLocationDot(style: dotStyle, reduceMotion: reduceMotion)
                                .position(locationPoint)
                                .transition(.opacity)
                        }
                    }
                }
                .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                    BoundaryCityConnectionAnchors(boundary: $0, boundaryCenter: projection.center)
                }
                .background(Color.clear)
            } else {
                Color.clear
            }
        }
        .onAppear {
            traceBoundary()
        }
        .onChange(of: traceToken) { _ in
            traceBoundary()
        }
        .onDisappear {
            locationDotTask?.cancel()
        }
        .accessibilityHidden(true)
    }

    /// Restarts the boundary trace and delays the approximate-location dot until the shape is established.
    private func traceBoundary() {
        locationDotTask?.cancel()
        withAnimation(.none) {
            traceProgress = reduceMotion ? 1 : 0
            showsLocationDot = false
        }

        if let animation = LociqMotion.boundaryTrace(reduceMotion: reduceMotion) {
            withAnimation(animation) {
                traceProgress = 1
            }
        }

        locationDotTask = Task { @MainActor in
            let delay = LociqMotion.locationDotRevealDelay(reduceMotion: reduceMotion)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(LociqMotion.locationDotReveal(reduceMotion: reduceMotion)) {
                showsLocationDot = true
            }
        }
    }
}

struct BoundaryCityConnectorLine: View {
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

    /// Restarts the one-time connector line animation.
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

struct BoundaryCityConnectionAnchors: Equatable {
    var boundary: Anchor<CGRect>?
    var boundaryCenter: CGPoint?
    var city: Anchor<CGRect>?
}

struct BoundaryCityConnectionPreferenceKey: PreferenceKey {
    static var defaultValue = BoundaryCityConnectionAnchors()

    /// Merges boundary and city anchors emitted by separate views.
    static func reduce(value: inout BoundaryCityConnectionAnchors, nextValue: () -> BoundaryCityConnectionAnchors) {
        let next = nextValue()
        value.boundary = next.boundary ?? value.boundary
        value.boundaryCenter = next.boundaryCenter ?? value.boundaryCenter
        value.city = next.city ?? value.city
    }
}

private struct BoundaryCityConnectorShape: Shape {
    let start: CGPoint
    let end: CGPoint

    /// Draws a straight connector between the boundary and city label.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct BoundaryPreviewShape: Shape {
    let projection: GeoJSONBoundaryProjection

    /// Draws the projected GeoJSON boundary inside the provided rect.
    func path(in rect: CGRect) -> Path {
        projection.path
    }
}

private struct LocationDotStyle {
    let tintOpacity: Double
    let ringOpacity: Double
    let coreDiameter: CGFloat
    let ringDiameter: CGFloat
    let pulseScale: CGFloat
    let isVisible: Bool

    /// Derives dot and ring appearance from Core Location horizontal accuracy.
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
