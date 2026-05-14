//
//  BoundaryPreview.swift
//  Lociq
//
//  Draws the city boundary and coordinates the approximate location pulse.
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

private struct BoundaryPreviewShape: Shape {
    let projection: GeoJSONBoundaryProjection

    /// Draws the projected GeoJSON boundary inside the provided rect.
    func path(in rect: CGRect) -> Path {
        projection.path
    }
}
