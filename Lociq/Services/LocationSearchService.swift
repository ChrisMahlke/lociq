import Foundation
import CoreLocation
import Contacts

struct LocationSearchResult: Identifiable, Hashable {
    enum MatchKind: Hashable {
        case zip
        case place
    }

    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let zipCode: String?
    let matchKind: MatchKind
    let displayQuery: String

    var id: String {
        let lat = String(format: "%.5f", coordinate.latitude)
        let lon = String(format: "%.5f", coordinate.longitude)
        return "\(title)|\(subtitle)|\(lat)|\(lon)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class LocationSearchService {
    func searchLocations(for rawQuery: String) async throws -> [LocationSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let placemarks: [CLPlacemark]
        if Self.isZipCode(query) {
            let address = CNMutablePostalAddress()
            address.postalCode = query
            placemarks = try await CLGeocoder().geocodePostalAddress(address)
        } else {
            placemarks = try await CLGeocoder().geocodeAddressString(query)
        }

        let results = placemarks.compactMap { placemark in
            makeResult(from: placemark, query: query)
        }

        return deduplicated(results)
    }

    func isZipCodeQuery(_ query: String) -> Bool {
        Self.isZipCode(query)
    }

    private static func isZipCode(_ query: String) -> Bool {
        query.range(of: AppStrings.Validation.zipRegex, options: .regularExpression) != nil
    }

    private func makeResult(from placemark: CLPlacemark, query: String) -> LocationSearchResult? {
        guard let location = placemark.location else { return nil }

        let isZipQuery = Self.isZipCode(query)
        let locality = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name
        let admin = placemark.administrativeArea
        let postalCode = placemark.postalCode

        let title: String
        if isZipQuery {
            title = locality ?? postalCode ?? query
        } else {
            title = locality ?? placemark.name ?? query
        }

        let subtitleParts: [String] = [
            admin,
            postalCode,
            placemark.country == "United States" ? nil : placemark.country
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        let subtitle = subtitleParts.joined(separator: " · ")
        let displayQuery = isZipQuery
            ? (postalCode ?? query)
            : [title, admin].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }.joined(separator: ", ")

        return LocationSearchResult(
            title: title,
            subtitle: subtitle,
            coordinate: location.coordinate,
            zipCode: postalCode,
            matchKind: isZipQuery ? .zip : .place,
            displayQuery: displayQuery.isEmpty ? query : displayQuery
        )
    }

    private func deduplicated(_ results: [LocationSearchResult]) -> [LocationSearchResult] {
        var seen = Set<String>()
        var unique: [LocationSearchResult] = []

        for result in results {
            if seen.insert(result.id).inserted {
                unique.append(result)
            }
        }

        return unique
    }
}
