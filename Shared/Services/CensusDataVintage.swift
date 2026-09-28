//
//  CensusDataVintage.swift
//  Lociq
//
//  Defines the one Census data vintage that every request and label uses.
//
//  ACS statistics, geocoder place codes, and boundary geometry must describe the
//  same geography. Driving all of them from one value keeps a place's numbers,
//  outline, and land area consistent, and keeps the provenance text honest.
//

import Foundation

/// The Census data release the app requests, labels, and caches.
///
/// Bump `current` once a year when the next ACS 5-year release is published.
/// The checklist in `docs/data-sources.md` ("Annual vintage update") lists what
/// to verify first: the geocoder vintage name, the generalized boundary service,
/// its layer ids, and the attribute types it returns.
nonisolated struct CensusDataVintage: Equatable, Sendable {
    /// Final year of the ACS 5-year period, such as `2024` for 2020–2024.
    let acsYear: Int

    /// The release currently requested by the app.
    static let current = CensusDataVintage(acsYear: 2024)

    /// Stable identifier persisted with cached profiles, such as `acs2024`.
    var identifier: String {
        "acs\(acsYear)"
    }

    /// Human-readable 5-year period, such as `2020–2024`.
    var periodLabel: String {
        "\(acsYear - 4)–\(acsYear)"
    }

    /// Census geocoder vintage whose place codes match this ACS release.
    ///
    /// The `ACS{year}_Current` vintage returns only places that exist in that
    /// ACS release, so every resolved place has matching statistics and a
    /// matching generalized boundary.
    var geocoderVintage: String {
        "ACS\(acsYear)_Current"
    }

    /// TIGERweb service with shoreline-clipped, generalized boundaries for this release.
    var boundaryServicePath: String {
        "Generalized_ACS\(acsYear)/Places_CouSub_ConCity_SubMCD"
    }

    /// Generalized layer id for incorporated places. Verify on each vintage bump.
    var incorporatedPlacesBoundaryLayerId: String {
        "10"
    }

    /// Generalized layer id for census-designated places. Verify on each vintage bump.
    var censusDesignatedPlacesBoundaryLayerId: String {
        "11"
    }

    /// Source line shown in the details footer, such as `ACS 5-YEAR · 2020–2024`.
    var sourceLabel: String {
        "ACS 5-YEAR · \(periodLabel)"
    }

    /// Source line used in share text.
    var shareSourceLabel: String {
        "U.S. Census Bureau ACS \(periodLabel) 5-year estimates"
    }

    /// Returns the vintage for a persisted identifier, or `nil` for unknown values.
    init?(identifier: String?) {
        guard
            let identifier,
            identifier.hasPrefix("acs"),
            let year = Int(identifier.dropFirst(3))
        else { return nil }
        self.init(acsYear: year)
    }

    /// Creates a vintage for the final year of an ACS 5-year period.
    init(acsYear: Int) {
        self.acsYear = acsYear
    }
}

/// Notice the Census Data API Terms of Service ask apps to display.
nonisolated enum CensusAttribution {
    /// Verbatim notice text from the Census Data API Terms of Service.
    static let apiNotice = "This product uses the Census Bureau Data API but is not endorsed or certified by the Census Bureau."
}
