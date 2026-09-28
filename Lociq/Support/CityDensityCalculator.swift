import Foundation

/// Calculates an honest, city-wide density from ACS population and TIGER geometry.
/// It intentionally returns one uniform value and never invents internal variation.
enum CityDensityCalculator {
    private static let earthRadiusMeters = 6_371_008.8
    private static let squareMetersPerSquareMile = 2_589_988.110336

    static func peoplePerSquareMile(
        populationText: String,
        boundary: GeoJSONFeatureCollection
    ) -> Double? {
        let digits = populationText.filter(\.isNumber)
        guard let population = Double(digits), population > 0 else { return nil }
        let area = GeoJSONBoundaryRings.exteriorRings(from: boundary)
            .reduce(0.0) { $0 + sphericalArea(of: $1) }
        guard area > 0 else { return nil }
        return population / (area / squareMetersPerSquareMile)
    }

    static func formatted(_ density: Double) -> String {
        density.formatted(.number.precision(.fractionLength(0))) + " / SQ MI"
    }

    /// Chamberlain-Duquette spherical polygon area, adequate for a quiet city glyph.
    private static func sphericalArea(of ring: [[Double]]) -> Double {
        guard ring.count > 2 else { return 0 }
        var sum = 0.0
        for index in ring.indices {
            let next = ring[(index + 1) % ring.count]
            guard ring[index].count >= 2, next.count >= 2 else { continue }
            let lon1 = ring[index][0] * .pi / 180
            let lon2 = next[0] * .pi / 180
            let lat1 = ring[index][1] * .pi / 180
            let lat2 = next[1] * .pi / 180
            sum += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }
        return abs(sum) * earthRadiusMeters * earthRadiusMeters / 2
    }
}
