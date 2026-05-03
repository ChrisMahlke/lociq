import CoreLocation
import Foundation

enum NeighborhoodDiscoveryCandidateFactory {
    nonisolated static func candidate(
        profile: ResolvedPlaceProfile,
        coordinate: CLLocationCoordinate2D,
        scale: BoundaryOverlayScale
    ) -> DiscoveryCandidateProfile {
        let demographics = demographics(from: profile, scale: scale)

        return DiscoveryCandidateProfile(
            id: profile.zipBundle.tract?.geoid ?? profile.zipBundle.zcta,
            title: profile.zipBundle.place?.name ?? demographics.name,
            subtitle: subtitle(bundle: profile.zipBundle, scale: scale),
            zipCode: profile.zipBundle.zcta,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            metrics: CensusMetricsMapper.metrics(from: demographics),
            demographics: demographics,
            preferredScale: scale
        )
    }

    nonisolated static func offsetCoordinate(
        from coordinate: CLLocationCoordinate2D,
        distanceKilometers: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let earthRadiusKm = 6_371.0
        let bearing = bearingDegrees * .pi / 180
        let distanceRatio = distanceKilometers / earthRadiusKm
        let startLat = coordinate.latitude * .pi / 180
        let startLon = coordinate.longitude * .pi / 180

        let endLat = asin(
            sin(startLat) * cos(distanceRatio) +
            cos(startLat) * sin(distanceRatio) * cos(bearing)
        )

        let endLon = startLon + atan2(
            sin(bearing) * sin(distanceRatio) * cos(startLat),
            cos(distanceRatio) - sin(startLat) * sin(endLat)
        )

        return CLLocationCoordinate2D(
            latitude: endLat * 180 / .pi,
            longitude: endLon * 180 / .pi
        )
    }

    nonisolated private static func demographics(from profile: ResolvedPlaceProfile, scale: BoundaryOverlayScale) -> Demographics {
        if scale == .tract {
            return profile.scaleDemographics.tract ?? profile.scaleDemographics.zip
        }

        return profile.scaleDemographics.zip
    }

    nonisolated private static func subtitle(bundle: ZipLookupResult, scale: BoundaryOverlayScale) -> String {
        var parts: [String] = []

        if let county = bundle.county?.name, !county.isEmpty {
            parts.append(county)
        }

        parts.append(AppStrings.Formats.zip(bundle.zcta))

        if scale == .tract, let tractCode = bundle.tract?.tractCode, !tractCode.isEmpty {
            parts.append(AppStrings.Formats.tract(tractCode))
        }

        return parts.joined(separator: " · ")
    }
}
