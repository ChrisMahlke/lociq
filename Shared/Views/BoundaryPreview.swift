//
//  BoundaryPreview.swift
//  Lociq
//
//  Draws the city boundary and coordinates the location marker.
//
//  The boundary is a geography glyph, not a map. It traces the projected city
//  outline, then reveals a small location marker after the outline has had
//  time to establish place context.
//

import CoreLocation
import SwiftUI

/// Minimal projected boundary preview for the currently resolved city.
///
/// The view places a precomputed glyph into its frame, animates the outline
/// once per place, and publishes anchor data so `ContentView` can draw the
/// connector to the city label.
struct CityBoundaryPreview: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// Outline built off the main actor for the displayed place.
    let glyph: BoundaryGlyph

    /// Optional user coordinate for the location marker.
    let coordinate: CLLocationCoordinate2D?

    /// Core Location accuracy used to size or hide the marker.
    let horizontalAccuracy: CLLocationAccuracy?

    /// True when the fix came from approximate location.
    let isApproximate: Bool

    /// City-wide density, which sets the dot texture's spacing.
    let densityPerSquareMile: Double?

    /// Token that restarts the boundary trace when the place changes.
    let traceToken: Int

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// Growth of strokes, the dot texture, and the marker for larger glyphs,
    /// such as on iPad. 1 on iPhone.
    var graphicScale: CGFloat = 1

    /// The frame the marker rules are measured in, when this view's frame
    /// hugs the outline (iPad, Apple Watch). Whether the marker shows, and
    /// whether a fix just outside the outline is drawn, then match the full
    /// frame the hugging one replaced. `nil` uses this view's frame.
    var markerFrameSize: CGSize?

    /// Current trim progress for the boundary outline.
    @State private var traceProgress: CGFloat = 0

    /// Whether the location marker should be visible.
    @State private var showsLocationDot = false

    /// Delayed reveal task for the location marker.
    @State private var locationDotTask: Task<Void, Never>?

    /// Places and renders the boundary inside the available frame.
    var body: some View {
        GeometryReader { proxy in
            let placement = glyph.placement(in: CGRect(origin: .zero, size: proxy.size))
            let markerBounds = markerBounds(in: proxy.size)
            let marker = markerStyle(for: placement, frameSize: markerBounds.size)
            let markerPoint = coordinate.flatMap { placement.point(for: $0, within: markerBounds) }

            ZStack {
                // One uniform fill gives the city shape informational weight
                // without suggesting unsupported sub-city variation. The
                // even-odd rule leaves enclaves (other places) unfilled.
                BoundaryGlyphShape(glyph: glyph)
                    .fill(Color.lociqText.opacity(isEmphasized ? 0.16 : 0.075), style: FillStyle(eoFill: true))

                BoundaryDotTexture(
                    spacing: BoundaryDotTexture.spacing(forDensity: densityPerSquareMile) * graphicScale,
                    dotSize: 1.1 * graphicScale
                )
                    .foregroundStyle(Color.lociqText.opacity(isEmphasized ? 0.16 : 0.09))
                    .mask {
                        BoundaryGlyphShape(glyph: glyph)
                            .fill(style: FillStyle(eoFill: true))
                    }

                // The path is trimmed from zero to one so the outline feels
                // drawn rather than abruptly appearing.
                BoundaryGlyphShape(glyph: glyph)
                    .trim(from: 0, to: traceProgress)
                    .stroke(
                        Color.lociqBoundaryHalo,
                        style: StrokeStyle(lineWidth: 2.7 * graphicScale, lineCap: .round, lineJoin: .round)
                    )

                BoundaryGlyphShape(glyph: glyph)
                    .trim(from: 0, to: traceProgress)
                    .stroke(
                        Color.lociqBoundaryStroke,
                        style: StrokeStyle(lineWidth: 1.0 * graphicScale, lineCap: .round, lineJoin: .round)
                    )

                if showsLocationDot, marker != .hidden, let markerPoint {
                    // The marker uses the same placement as the outline, so it
                    // stays spatially aligned with it.
                    PulsingLocationDot(style: marker, reduceMotion: reduceMotion, scale: graphicScale)
                        .position(markerPoint)
                        .transition(.opacity)
                }
            }
            .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                BoundaryCityConnectionAnchors(boundary: $0, boundaryCenter: placement.anchor)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription(marker: markerPoint == nil ? .hidden : marker))
            .accessibilityIdentifier("boundary.glyph")
        }
        .onAppear {
            traceBoundary()
        }
        .onChangeOf(traceToken) { _ in
            traceBoundary()
        }
        .onDisappear {
            locationDotTask?.cancel()
        }
    }

    /// True when fills should use their higher-contrast values.
    private var isEmphasized: Bool {
        reduceTransparency || colorSchemeContrast == .increased
    }

    /// Chooses the marker for the current fix and glyph scale.
    private func markerStyle(for placement: BoundaryGlyphPlacement, frameSize: CGSize) -> LocationMarkerStyle {
        guard let coordinate else { return .hidden }
        return LocationMarkerStyle.make(
            accuracyMeters: horizontalAccuracy,
            isApproximate: isApproximate,
            glyphSize: frameSize
        ) { meters in
            placement.points(forMeters: meters, atLatitude: coordinate.latitude)
        }
    }

    /// The marker frame, centered on this view's frame.
    private func markerBounds(in size: CGSize) -> CGRect {
        guard let reference = markerFrameSize else { return CGRect(origin: .zero, size: size) }
        return CGRect(
            x: (size.width - reference.width) / 2,
            y: (size.height - reference.height) / 2,
            width: reference.width,
            height: reference.height
        )
    }

    /// Restarts the boundary trace and delays the marker until the shape is established.
    ///
    /// The marker reveal is delayed so the user first perceives the place
    /// boundary, then the location within it. The task is cancelled whenever
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

    /// Describes the glyph, mentioning the marker only when it is drawn.
    private func accessibilityDescription(marker: LocationMarkerStyle) -> String {
        switch marker {
        case .precise: return "City boundary, with your location marked"
        case .area: return "City boundary, with your approximate area marked"
        case .hidden: return "City boundary"
        }
    }
}

/// A faint, even micro-dot field. Uniform spacing communicates city-wide
/// density without resembling a neighborhood choropleth.
private struct BoundaryDotTexture: View {
    /// Distance between dot centers.
    let spacing: CGFloat

    /// Diameter of each dot.
    var dotSize: CGFloat = 1.1

    /// Dot spacing for a city-wide density: denser places get a finer field.
    ///
    /// The spacing is uniform within a city, so it implies the city's overall
    /// density without suggesting variation inside it. Unknown density keeps
    /// the neutral spacing.
    static func spacing(forDensity density: Double?) -> CGFloat {
        guard let density, density > 0 else { return 9 }
        let spacing = 14 - 1.6 * log10(max(density, 1))
        return CGFloat(min(max(spacing, 7), 12))
    }

    var body: some View {
        Canvas { context, size in
            for y in stride(from: spacing / 2, through: size.height, by: spacing) {
                for x in stride(from: spacing / 2, through: size.width, by: spacing) {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                        with: .foreground
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// SwiftUI shape that scales a unit-space glyph into its rect.
///
/// Only an affine transform runs per frame; projection math ran once, off the
/// main actor, when the glyph was built.
private struct BoundaryGlyphShape: Shape {
    let glyph: BoundaryGlyph

    func path(in rect: CGRect) -> Path {
        glyph.placement(in: rect).path
    }
}
