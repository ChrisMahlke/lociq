//
//  ACSDemographicsVariableCatalog.swift
//  Lociq
//
//  Defines the ACS variable set used to build the city demographic snapshot.
//
//  This is the only file that should list raw ACS variable codes for the LOC IQ
//  city profile. The mapper owns the semantic meaning of each code. Keeping the
//  catalog isolated makes it easier to audit Census dependencies and add or
//  remove fields without touching UI code.
//

import Foundation

/// Catalog of ACS estimate variables requested for a place-level profile.
///
/// The list covers the summary metrics and the details view. Variables are
/// requested in chunks by `ACSDemographicsClient`.
nonisolated enum ACSDemographicsVariableCatalog {
    /// Conservative per-request variable limit used when splitting ACS calls.
    ///
    /// The API can support more in some cases, but keeping chunks smaller makes
    /// URLs easier to inspect and reduces failure blast radius.
    static let maxVariablesPerRequest = 45

    /// ACS variables required to assemble the current city demographic profile.
    ///
    /// `NAME` is included alongside estimate variables so ACS can provide the
    /// authoritative place label when available. Entries ending in `E` are
    /// estimates. Entries ending in `EA` are estimate annotations, requested for
    /// the displayed medians because ACS reports medians in an open-ended top or
    /// bottom interval as a bound (for example `250,000+`).
    ///
    /// Every variable here is displayed or used to derive a displayed value.
    /// Remove a variable together with the last feature that uses it.
    static let extendedVariables = [
        "NAME",
        // Population and median age.
        "B01003_001E",
        "B01002_001E",
        // Median household income, home value, and gross rent, with annotations.
        "B19013_001E",
        "B19013_001EA",
        "B25077_001E",
        "B25077_001EA",
        "B25064_001E",
        "B25064_001EA",
        // Tenure (occupied units by owner and renter).
        "B25003_002E",
        "B25003_003E",
        // Occupancy status (all housing units and vacant units).
        "B25002_001E",
        "B25002_003E",
        // Commuting: all workers, transit, worked from home, aggregate travel time.
        "B08301_001E",
        "B08301_010E",
        "B08301_021E",
        "B08013_001E",
        // Sex by age, combined into broad age bands.
        "B01001_001E",
        "B01001_003E",
        "B01001_004E",
        "B01001_005E",
        "B01001_006E",
        "B01001_007E",
        "B01001_008E",
        "B01001_009E",
        "B01001_010E",
        "B01001_011E",
        "B01001_012E",
        "B01001_013E",
        "B01001_014E",
        "B01001_015E",
        "B01001_016E",
        "B01001_017E",
        "B01001_018E",
        "B01001_019E",
        "B01001_020E",
        "B01001_021E",
        "B01001_022E",
        "B01001_023E",
        "B01001_024E",
        "B01001_025E",
        "B01001_027E",
        "B01001_028E",
        "B01001_029E",
        "B01001_030E",
        "B01001_031E",
        "B01001_032E",
        "B01001_033E",
        "B01001_034E",
        "B01001_035E",
        "B01001_036E",
        "B01001_037E",
        "B01001_038E",
        "B01001_039E",
        "B01001_040E",
        "B01001_041E",
        "B01001_042E",
        "B01001_043E",
        "B01001_044E",
        "B01001_045E",
        "B01001_046E",
        "B01001_047E",
        "B01001_048E",
        "B01001_049E",
        // Educational attainment for the population 25 years and over.
        "B15003_001E",
        "B15003_022E",
        "B15003_023E",
        "B15003_024E",
        "B15003_025E"
    ]
}
