//
//  DemographicValueFormatter.swift
//  Lociq
//
//  Formats demographic values and Census geography names for compact display.
//
//  Formatting is centralized so the UI never needs to understand ACS units,
//  missing values, currency rules, or noisy Census geography suffixes.
//

import Foundation

/// Presentation formatter for normalized demographic and geography values.
///
/// Every unavailable value is represented by the same compact marker, `--`.
/// That consistency is important in the sparse UI because there is no room for
/// per-field explanatory text.
enum DemographicValueFormatter {
    /// Returns the display title for a resolved city profile.
    ///
    /// This overload uses geocoder metadata only. It is the preferred path when
    /// a reliable `PlaceInfo` exists.
    static func title(from profile: ResolvedCityProfile) -> String {
        title(from: profile.geography)
    }

    /// Returns the display title, falling back to the ACS row name when geocoder metadata is incomplete.
    ///
    /// ACS often includes a readable `NAME` value. When the geocoder collapses
    /// to the generic fallback `CITY`, this method lets ACS provide the label.
    static func title(from profile: ResolvedCityProfile, demographics: Demographics) -> String {
        let geographyTitle = title(from: profile)
        guard geographyTitle == "CITY", !demographics.name.isEmpty else {
            return geographyTitle
        }
        return cleanGeographyName(demographics.name)
    }

    /// Returns the display title from Census geocoder geography.
    ///
    /// Place name is preferred over county name because the app presents
    /// city-level data. County name is only a fallback for non-demographic
    /// location shells.
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
    ///
    /// This variant accepts the app-domain geography type used in resolved
    /// profiles after the geocoder response has been normalized.
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
    ///
    /// Fallback shells use this to avoid implying county-level data is being
    /// displayed as city-level data.
    static func cityTitle(from geography: CensusGeographiesBundle) -> String? {
        guard let placeName = geography.place?.name, !placeName.isEmpty else {
            return nil
        }

        return cleanGeographyName(placeName)
    }

    /// Returns occupied households, falling back to total housing units when occupancy values are unavailable.
    ///
    /// Owner and renter occupied counts provide the best household estimate.
    /// Total housing units is less precise for households, but better than
    /// showing nothing when tenure fields are unavailable.
    static func households(from demographics: Demographics) -> Int? {
        if let owner = demographics.housing.ownerOccupied, let renter = demographics.housing.renterOccupied {
            return owner + renter
        }
        return demographics.housing.units
    }

    /// Formats an integer for compact display.
    ///
    /// - Returns: A locale-aware integer string or `--`.
    static func number(_ value: Int?) -> String {
        guard let value else { return "--" }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    /// Formats a currency value or returns the unavailable marker.
    ///
    /// Currency is currently U.S. dollars because the data source is U.S.
    /// Census ACS.
    static func currency(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "--" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// Formats a one-decimal numeric value or returns the unavailable marker.
    ///
    /// Used for median age and other small decimal estimates where one decimal
    /// place adds useful precision without visual clutter.
    static func decimal(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return String(format: "%.1f", value)
    }

    /// Formats a percentage value or returns the unavailable marker.
    ///
    /// Percentages are rounded to whole numbers to keep the interface quiet and
    /// scannable.
    static func percent(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    /// Formats a minute duration or returns the unavailable marker.
    ///
    /// Used for commute time. The `MIN` suffix avoids adding separate unit text
    /// in the view layer.
    static func minutes(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded())) MIN"
    }

    /// Removes Census geography suffixes that make city names feel noisy in the minimal UI.
    ///
    /// Census names often include legal or statistical suffixes such as `city`,
    /// `town`, and `CDP`. Removing them keeps the displayed place label aligned
    /// with how people usually refer to the place.
    private static func cleanGeographyName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " city", with: "")
            .replacingOccurrences(of: " town", with: "")
            .replacingOccurrences(of: " CDP", with: "")
            .replacingOccurrences(of: ", United States", with: "")
    }
}
