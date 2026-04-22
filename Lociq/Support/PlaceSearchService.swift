import CoreLocation
import Foundation
import MapKit

struct PlaceSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    nonisolated init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.id = [
            title,
            subtitle,
            String(format: "%.5f", coordinate.latitude),
            String(format: "%.5f", coordinate.longitude)
        ].joined(separator: "::")
    }

    static func == (lhs: PlaceSearchResult, rhs: PlaceSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

protocol PlaceSearchServing {
    func search(query: String) async throws -> [PlaceSearchResult]
}

struct ApplePlaceSearchService: PlaceSearchServing {
    init() {}

    func search(query: String) async throws -> [PlaceSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery

        let response = try await MKLocalSearch(request: request).start()
        var seenIDs = Set<String>()

        return response.mapItems.compactMap { item in
            let coordinate = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

            let title = formattedTitle(for: item)
            guard !title.isEmpty else { return nil }

            let result = PlaceSearchResult(
                title: title,
                subtitle: formattedSubtitle(for: item.placemark),
                coordinate: coordinate
            )

            guard !seenIDs.contains(result.id) else { return nil }
            seenIDs.insert(result.id)
            return result
        }
    }

    private func formattedTitle(for item: MKMapItem) -> String {
        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }

        if let thoroughfare = item.placemark.thoroughfare, !thoroughfare.isEmpty {
            return thoroughfare
        }

        if let locality = item.placemark.locality, !locality.isEmpty {
            return locality
        }

        return item.placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func formattedSubtitle(for placemark: MKPlacemark) -> String {
        let rawComponents: [String?] = [
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        let components = rawComponents.compactMap { component -> String? in
            guard let component else { return nil }
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return Array(NSOrderedSet(array: components)).compactMap { $0 as? String }.joined(separator: ", ")
    }
}
