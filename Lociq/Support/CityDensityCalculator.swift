//
//  CityDensityCalculator.swift
//  Lociq
//
//  Calculates the city-wide population density shown under the boundary glyph.
//

import Foundation

/// Calculates an honest, city-wide density from ACS population and Census land area.
///
/// Density uses Census `AREALAND`, the published land area of the place, the
/// same basis Census uses. Polygon area would count water and enclaves as part
/// of the city. The result is one uniform value and never implies internal
/// variation.
nonisolated enum CityDensityCalculator {
    /// Square meters in one square mile.
    static let squareMetersPerSquareMile = 2_589_988.110336

    /// People per square mile of land, or `nil` when either input is unavailable.
    static func peoplePerSquareMile(population: Int?, landAreaSquareMeters: Double?) -> Double? {
        guard
            let population, population > 0,
            let landAreaSquareMeters, landAreaSquareMeters > 0
        else { return nil }
        return Double(population) / (landAreaSquareMeters / squareMetersPerSquareMile)
    }

    /// Formats density to two significant figures, such as `18,000` or `<1`.
    ///
    /// Two figures match the precision of an ACS estimate divided by a land
    /// area; more digits would look more certain than the data are.
    static func formattedValue(_ density: Double, locale: Locale = .current) -> String {
        guard density >= 1 else { return "<1" }
        return density.formatted(.number.precision(.significantDigits(1...2)).locale(locale))
    }

    /// Formats density with its unit, such as `18,000 / SQ MI`.
    static func formatted(_ density: Double, locale: Locale = .current) -> String {
        "\(formattedValue(density, locale: locale)) / SQ MI"
    }

    /// Spoken form, such as "about 18,000 people per square mile".
    static func spoken(_ density: Double, locale: Locale = .current) -> String {
        guard density >= 1 else { return "fewer than 1 person per square mile" }
        return "about \(formattedValue(density, locale: locale)) people per square mile"
    }
}
