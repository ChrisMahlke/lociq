//
//  DemographicValueFormatter.swift
//  Lociq
//
//  Formats demographic values and Census geography names for compact display.
//

import Foundation

enum DemographicValueFormatter {
    /// Returns the display title for a resolved city profile.
    static func title(from profile: ResolvedCityProfile) -> String {
        title(from: profile.geography)
    }

    /// Returns the display title from Census geocoder geography.
    static func title(from geography: CensusGeographiesBundle) -> String {
        if let placeName = geography.place?.name, !placeName.isEmpty {
            return cleanGeographyName(placeName)
        }
        if let countyName = geography.county?.name, !countyName.isEmpty {
            return cleanGeographyName(countyName)
        }
        return "CITY"
    }

    /// Returns the display title from normalized city geography.
    static func title(from geography: CityGeographyProfile) -> String {
        if let placeName = geography.place?.name, !placeName.isEmpty {
            return cleanGeographyName(placeName)
        }
        if let countyName = geography.county?.name, !countyName.isEmpty {
            return cleanGeographyName(countyName)
        }
        return "CITY"
    }

    /// Returns a city-only display title when a place match exists.
    static func cityTitle(from geography: CensusGeographiesBundle) -> String? {
        guard let placeName = geography.place?.name, !placeName.isEmpty else {
            return nil
        }

        return cleanGeographyName(placeName)
    }

    /// Returns occupied households, falling back to total housing units when occupancy values are unavailable.
    static func households(from demographics: Demographics) -> Int? {
        if let owner = demographics.housing.ownerOccupied, let renter = demographics.housing.renterOccupied {
            return owner + renter
        }
        return demographics.housing.units
    }

    /// Formats an integer for compact display.
    static func number(_ value: Int?) -> String {
        guard let value else { return "--" }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    /// Formats a currency value or returns the unavailable marker.
    static func currency(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "--" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// Formats a one-decimal numeric value or returns the unavailable marker.
    static func decimal(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return String(format: "%.1f", value)
    }

    /// Formats a percentage value or returns the unavailable marker.
    static func percent(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    /// Formats a minute duration or returns the unavailable marker.
    static func minutes(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded())) MIN"
    }

    /// Removes Census geography suffixes that make city names feel noisy in the minimal UI.
    private static func cleanGeographyName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " city", with: "")
            .replacingOccurrences(of: " town", with: "")
            .replacingOccurrences(of: " CDP", with: "")
            .replacingOccurrences(of: ", United States", with: "")
    }
}
