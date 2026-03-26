//
//  GoogleMapViewRepresentable.swift
//  Lociq
//
//  SwiftUI wrapper around `GMSMapView` that handles taps and boundary polygon rendering.
//

import SwiftUI
import GoogleMaps
import CoreLocation

/// Bridges Google Maps UIKit APIs into SwiftUI.
struct GoogleMapViewRepresentable: UIViewRepresentable {
    private static let defaultCamera = GMSCameraPosition(latitude: 37.7749, longitude: -122.4194, zoom: 12)

    /// Shared map instance to preserve camera and avoid recreating expensive map resources.
    private static var sharedMapView: GMSMapView = makeMapView()

    @Binding var tappedCoordinate: CLLocationCoordinate2D?
    let selectedBoundary: GeoJSONFeatureCollection?
    let selectedScale: BoundaryOverlayScale

    init(
        tappedCoordinate: Binding<CLLocationCoordinate2D?>,
        selectedBoundary: GeoJSONFeatureCollection?,
        selectedScale: BoundaryOverlayScale = .zip
    ) {
        self._tappedCoordinate = tappedCoordinate
        self.selectedBoundary = selectedBoundary
        self.selectedScale = selectedScale
    }

    /// Builds the base Google map configuration used for the shared map instance.
    private static func makeMapView() -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = defaultCamera
        options.frame = .zero

        let mapView = GMSMapView(options: options)
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        return mapView
    }

    /// Centers on either the user's location or the last selected coordinate.
    static func focusOnUserOrSelection(selection: CLLocationCoordinate2D?) {
        let mapView = sharedMapView
        if let userCoordinate = mapView.myLocation?.coordinate {
            let camera = GMSCameraPosition(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude, zoom: max(mapView.camera.zoom, 13))
            mapView.animate(to: camera)
            return
        }

        if let selection {
            let camera = GMSCameraPosition(latitude: selection.latitude, longitude: selection.longitude, zoom: max(mapView.camera.zoom, 13))
            mapView.animate(to: camera)
        }
    }

    /// Resets to the app's default city overview camera.
    static func resetCamera() {
        sharedMapView.animate(to: defaultCamera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = Self.sharedMapView
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        uiView.delegate = context.coordinator
        context.coordinator.updateBoundaryOverlay(on: uiView, with: selectedBoundary, scale: selectedScale)
    }

    /// Handles `GMSMapViewDelegate` callbacks and boundary overlay lifecycle.
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapViewRepresentable
        private var boundaryOverlays: [GMSPolygon] = []
        private let locationManager = CLLocationManager()
        private weak var mapView: GMSMapView?
        private var hasCenteredOnUserLocation = false

        init(_ parent: GoogleMapViewRepresentable) {
            self.parent = parent
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }

        /// Captures map taps and forwards the selected coordinate back to SwiftUI state.
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            // Immediately clear the previous selection overlay so the map reflects
            // the new tap while async boundary fetching is still in progress.
            clearBoundaryOverlays()
            parent.tappedCoordinate = coordinate
        }

        /// Replaces currently rendered boundaries with the latest selected feature collection.
        func updateBoundaryOverlay(on mapView: GMSMapView, with featureCollection: GeoJSONFeatureCollection?, scale: BoundaryOverlayScale) {
            self.mapView = mapView
            updateLocationAuthorizationState()

            clearBoundaryOverlays()

            guard let featureCollection else { return }

            for feature in featureCollection.features {
                guard let geometry = feature.geometry else { continue }
                boundaryOverlays.append(contentsOf: makePolygons(from: geometry, mapView: mapView, scale: scale))
            }
        }

        private func clearBoundaryOverlays() {
            boundaryOverlays.forEach { $0.map = nil }
            boundaryOverlays.removeAll()
        }

        /// Converts GeoJSON geometry values into Google Maps polygons.
        private func makePolygons(from geometry: GeoJSONGeometry, mapView: GMSMapView, scale: BoundaryOverlayScale) -> [GMSPolygon] {
            switch geometry {
            case .polygon(let rings):
                guard let polygon = polygonFromRings(rings, mapView: mapView, scale: scale) else { return [] }
                return [polygon]
            case .multiPolygon(let polygons):
                return polygons.compactMap { polygonFromRings($0, mapView: mapView, scale: scale) }
            case .other:
                return []
            }
        }

        /// Creates a `GMSPolygon` from GeoJSON rings, including optional interior holes.
        private func polygonFromRings(_ rings: [[[Double]]], mapView: GMSMapView, scale: BoundaryOverlayScale) -> GMSPolygon? {
            guard let outerRing = rings.first else { return nil }
            let outerPath = makePath(from: outerRing)
            guard outerPath.count() > 0 else { return nil }

            let polygon = GMSPolygon(path: outerPath)
            let holePaths = rings.dropFirst().map(makePath(from:))
            polygon.holes = holePaths.filter { $0.count() > 0 }

            let style = boundaryStyle(for: scale)
            polygon.strokeColor = style.stroke
            polygon.strokeWidth = 2.5
            polygon.fillColor = style.fill
            polygon.map = mapView
            return polygon
        }

        private func boundaryStyle(for scale: BoundaryOverlayScale) -> (stroke: UIColor, fill: UIColor) {
            switch scale {
            case .zip:
                let stroke = UIColor.systemBlue
                return (stroke, stroke.withAlphaComponent(0.09))
            case .tract:
                let stroke = UIColor.systemTeal
                return (stroke, stroke.withAlphaComponent(0.18))
            }
        }

        /// Converts coordinate pairs in `[longitude, latitude]` format into a map path.
        private func makePath(from coordinates: [[Double]]) -> GMSMutablePath {
            let path = GMSMutablePath()

            for coordinatePair in coordinates where coordinatePair.count >= 2 {
                let longitude = coordinatePair[0]
                let latitude = coordinatePair[1]
                path.add(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }

            return path
        }

        private func updateLocationAuthorizationState() {
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.startUpdatingLocation()
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                locationManager.stopUpdatingLocation()
            @unknown default:
                locationManager.stopUpdatingLocation()
            }
        }
    }
}

extension GoogleMapViewRepresentable.Coordinator: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateLocationAuthorizationState()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard
            !hasCenteredOnUserLocation,
            let location = locations.last,
            let mapView
        else {
            return
        }

        hasCenteredOnUserLocation = true
        let coordinate = location.coordinate
        parent.tappedCoordinate = coordinate
        mapView.animate(toLocation: coordinate)
        mapView.animate(toZoom: 13)
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("Location update failed", error)
        #endif
    }
}
