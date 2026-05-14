//
//  BoundaryPreview.swift
//  Lociq
//
//  Draws the city boundary and coordinates the approximate location pulse.
//
//  The boundary is a geography glyph, not a map. It traces the projected city
//  outline, then reveals a small approximate-location marker after the outline
//  has had time to establish place context.
//

import CoreLocation
import SwiftUI

/// Minimal projected boundary preview for the currently resolved city.
///
/// The view projects GeoJSON into its local frame, animates the outline once,
/// and publishes anchor data so `ContentView` can draw the connector to the
/// city label.
struct CityBoundaryPreview: View {
    /// GeoJSON city or CDP boundary to draw.
    let boundary: GeoJSONFeatureCollection

    /// Optional user coordinate for the approximate-location dot.
    let coordinate: CLLocationCoordinate2D?

    /// Core Location accuracy used to style or hide the dot.
    let horizontalAccuracy: CLLocationAccuracy?

    /// Token that restarts the boundary trace when profile data changes.
    let traceToken: Int

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// Current trim progress for the boundary outline.
    @State private var traceProgress: CGFloat = 0

    /// Whether the approximate-location dot should be visible.
    @State private var showsLocationDot = false

    /// Delayed reveal task for the location dot.
    @State private var locationDotTask: Task<Void, Never>?

    /// Projects and renders the boundary inside the available frame.
    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)

            if let projection = GeoJSONBoundaryPathBuilder.projection(for: boundary, in: rect) {
                ZStack {
                    // The path is trimmed from zero to one so the outline feels
                    // drawn rather than abruptly appearing.
                    BoundaryPreviewShape(projection: projection)
                        .trim(from: 0, to: traceProgress)
                        .stroke(
                            Color.white.opacity(0.28),
                            style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                        )

                    if showsLocationDot, let coordinate, let locationPoint = projection.point(for: coordinate) {
                        // The dot uses the same projection object as the path,
                        // so it remains spatially aligned with the outline.
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
    ///
    /// The dot reveal is delayed so the user first perceives the place boundary,
    /// then the approximate location within it. The task is cancelled whenever
    /// the view disappears or a new trace starts.
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

/// SwiftUI shape wrapper around a precomputed projected GeoJSON path.
private struct BoundaryPreviewShape: Shape {
    /// Projection that already contains the fitted path.
    let projection: GeoJSONBoundaryProjection

    /// Draws the projected GeoJSON boundary inside the provided rect.
    func path(in rect: CGRect) -> Path {
        projection.path
    }
}
