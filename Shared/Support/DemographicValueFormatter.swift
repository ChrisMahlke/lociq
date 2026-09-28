//
//  DemographicValueFormatter.swift
//  Lociq
//
//  Formats demographic values and Census geography names for compact display.
//
//  Formatting is centralized so the UI never needs to understand ACS units,
//  missing values, currency rules, or Census geography descriptors.
//

import Foundation

/// Presentation formatter for normalized demographic and geography values.
///
/// Every unavailable value is represented by the same compact marker, `--`.
/// That consistency is important in the sparse UI because there is no room for
/// per-field explanatory text.
nonisolated enum DemographicValueFormatter {
    /// Display names for the eight consolidated "(balance)" places.
    ///
    /// For these places the Census base name equals the full legal name, such
    /// as "Nashville-Davidson metropolitan government (balance)", so the common
    /// name comes from this table, keyed by place GEOID.
    private static let balancePlaceNames: [String: String] = [
        "0947515": "Milford",
        "1303440": "Athens",
        "1304204": "Augusta",
        "1836003": "Indianapolis",
        "2028412": "Greeley County",
        "2148006": "Louisville",
        "3011397": "Butte",
        "4752006": "Nashville"
    ]

    /// Legal descriptors removed from the end of a place name when no base name is available.
    ///
    /// Longer descriptors come first so "city and borough" is removed whole.
    private static let placeDescriptors = [
        " metropolitan government (balance)",
        " consolidated government (balance)",
        " unified government (balance)",
        " metro government (balance)",
        " city and borough",
        " consolidated government",
        " metropolitan government",
        " unified government",
        " metro township",
        " urban county",
        " municipality",
        " zona urbana",
        " corporation",
        " (balance)",
        " comunidad",
        " borough",
        " village",
        " city",
        " town",
        " CDP"
    ]

    /// USPS abbreviations keyed by two-digit state FIPS code.
    private static let stateAbbreviations: [String: String] = [
        "01": "AL", "02": "AK", "04": "AZ", "05": "AR", "06": "CA", "08": "CO", "09": "CT", "10": "DE",
        "11": "DC", "12": "FL", "13": "GA", "15": "HI", "16": "ID", "17": "IL", "18": "IN", "19": "IA",
        "20": "KS", "21": "KY", "22": "LA", "23": "ME", "24": "MD", "25": "MA", "26": "MI", "27": "MN",
        "28": "MS", "29": "MO", "30": "MT", "31": "NE", "32": "NV", "33": "NH", "34": "NJ", "35": "NM",
        "36": "NY", "37": "NC", "38": "ND", "39": "OH", "40": "OK", "41": "OR", "42": "PA", "44": "RI",
        "45": "SC", "46": "SD", "47": "TN", "48": "TX", "49": "UT", "50": "VT", "51": "VA", "53": "WA",
        "54": "WV", "55": "WI", "56": "WY", "72": "PR"
    ]

    /// Returns the common name of a place, without its legal descriptor.
    ///
    /// Prefers the Census base name ("Juneau" rather than "Juneau city and
    /// borough"), then the "(balance)" table, then descriptor removal on the
    /// legal name.
    static func placeName(for place: PlaceInfo) -> String {
        if let geoid = place.geoid, let name = balancePlaceNames[geoid] {
            return name
        }
        if let baseName = place.baseName?.trimmingCharacters(in: .whitespaces),
           !baseName.isEmpty,
           !baseName.hasSuffix("(balance)") {
            return baseName
        }
        return cleanGeographyName(place.name)
    }

    /// Returns the display title for a place: its common name plus the state.
    ///
    /// The state abbreviation disambiguates common names such as Portland or
    /// Springfield. Callers uppercase the result for the header.
    static func placeTitle(for place: PlaceInfo) -> String {
        let name = placeName(for: place)
        guard let state = place.stateFIPS.flatMap({ stateAbbreviations[$0] }) else { return name }
        return "\(name), \(state)"
    }

    /// Returns a county's display name, such as `Middlesex County`.
    static func countyTitle(for county: CountyInfo) -> String {
        let name = county.name.trimmingCharacters(in: .whitespaces)
        guard let state = county.stateFIPS.flatMap({ stateAbbreviations[$0] }) else { return name }
        return "\(name), \(state)"
    }

    /// Returns occupied households, falling back to occupied units from occupancy status.
    ///
    /// Owner plus renter occupied units is the tenure universe. When tenure is
    /// unavailable, all units minus vacant units gives the same universe. All
    /// units alone would include vacant homes and is never used.
    static func households(from demographics: Demographics) -> Int? {
        if let owner = demographics.housing.ownerOccupied, let renter = demographics.housing.renterOccupied {
            return owner + renter
        }
        if let total = demographics.housing.totalUnits, let vacant = demographics.housing.vacantUnits, total >= vacant {
            return total - vacant
        }
        return nil
    }

    /// Formats an integer for compact display.
    ///
    /// - Returns: A locale-aware integer string or `--`.
    static func number(_ value: Int?, locale: Locale = .current) -> String {
        guard let value else { return "--" }
        return value.formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    /// Formats a currency value or returns the unavailable marker.
    ///
    /// Currency is U.S. dollars because the data source is U.S. Census ACS. A
    /// median in an open-ended interval keeps its Census annotation, as in
    /// `$250,000+`.
    static func currency(_ value: Int?, bound: MedianBound? = nil, locale: Locale = .current) -> String {
        guard let value, value >= 0 else { return "--" }
        let text = value.formatted(.currency(code: "USD").precision(.fractionLength(0)).locale(locale))
        switch bound {
        case .atLeast: return text + "+"
        case .atMost: return text + "-"
        case nil: return text
        }
    }

    /// Formats a one-decimal numeric value or returns the unavailable marker.
    ///
    /// Used for median age, where one decimal place adds useful precision
    /// without visual clutter.
    static func decimal(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return String(format: "%.1f", value)
    }

    /// Rounds a percentage to the whole number the UI shows, or `nil` when unavailable.
    static func wholePercent(_ value: Double?) -> Int? {
        guard let value, value >= 0 else { return nil }
        return Int(value.rounded())
    }

    /// Formats a percentage value or returns the unavailable marker.
    ///
    /// Percentages are rounded to whole numbers to keep the interface quiet and
    /// scannable.
    static func percent(_ value: Double?) -> String {
        guard let whole = wholePercent(value) else { return "--" }
        return "\(whole)%"
    }

    /// Formats a minute duration or returns the unavailable marker.
    ///
    /// Used for commute time. The `MIN` suffix avoids adding separate unit text
    /// in the view layer.
    static func minutes(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "--" }
        return "\(Int(value.rounded())) MIN"
    }

    /// Drops a two-letter state from a display title, for tight spaces such
    /// as watch complications: `SAN FRANCISCO, CA` becomes `SAN FRANCISCO`.
    ///
    /// Titles without a trailing state are returned unchanged.
    static func titleWithoutState(_ title: String) -> String {
        guard let comma = title.lastIndex(of: ",") else { return title }
        let state = title[title.index(after: comma)...].trimmingCharacters(in: .whitespaces)
        guard state.count == 2, state.allSatisfy(\.isLetter) else { return title }
        return String(title[..<comma])
    }

    /// Formats a count in few characters: in full below 10,000, otherwise
    /// abbreviated, such as `830K` or `1.2M`.
    static func compactCount(_ value: Int?, locale: Locale = .current) -> String {
        guard let value, value >= 0 else { return "--" }
        guard value >= 10_000 else {
            return value.formatted(.number.locale(locale))
        }
        return value.formatted(.number.notation(.compactName).locale(locale))
    }

    /// Removes a trailing Census legal descriptor from a place name.
    ///
    /// Only a descriptor at the end of the place part is removed, so names that
    /// contain descriptor words ("Town and Country", "Villages") stay intact.
    /// Anything after the first comma (a state in ACS names) is kept.
    static func cleanGeographyName(_ name: String) -> String {
        let parts = name.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        var place = String(parts.first ?? "").trimmingCharacters(in: .whitespaces)
        // "Indianapolis city (balance)" carries two descriptors, so repeat
        // until none remains. Matching is case-sensitive: "Carson City" keeps
        // its capitalized "City", which is part of the name.
        while let descriptor = placeDescriptors.first(where: { place.hasSuffix($0) && place.count > $0.count }) {
            place = String(place.dropLast(descriptor.count))
        }
        guard parts.count > 1 else { return place }
        let rest = String(parts[1]).trimmingCharacters(in: .whitespaces)
        return rest.isEmpty || rest == "United States" ? place : "\(place), \(rest)"
    }
}
