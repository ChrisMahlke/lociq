import Foundation

enum AppStrings {
    enum Validation {
        static let zipRegex = "^[0-9]{5}$"
        static let tractRegex = "^[0-9]{11}$"
        static let blockRegex = "^[0-9]{15}$"
    }

    enum Symbols {
        static let emDash = "—"
        static let oneDecimalFormat = "%.1f"
        static let oneDecimalPercentFormat = "%.1f%%"
    }

    enum Tabs {
        static var map: String { L10n.tr("Map") }
        static var more: String { L10n.tr("More") }
    }

    enum Metrics {
        static var population: String { L10n.tr("Population") }
        static var medianIncome: String { L10n.tr("Median Income") }
        static var medianAge: String { L10n.tr("Median Age") }
        static var households: String { L10n.tr("Households") }
    }

    enum Labels {
        static var swipeUpForMoreData: String { L10n.tr("Swipe up for more data") }
        static var insights: String { L10n.tr("Insights") }
        static var selectedArea: String { L10n.tr("Selected area") }
        static var noSelectionTitle: String { L10n.tr("Start with the map") }
        static var noSelectionBody: String { L10n.tr("Tap anywhere to load a neighborhood profile, compare ZIP and tract views, and read the area at a glance.") }
        static var loadingSelectionTitle: String { L10n.tr("Loading area profile") }
        static var loadingSelectionBody: String { L10n.tr("Fetching boundaries, Census context, and quick-read signals for your selected location.") }
        static var noCoverageTitle: String { L10n.tr("No neighborhood profile here") }
        static var noCoverageBody: String { L10n.tr("This point does not map to a ZIP-backed neighborhood profile. Try a nearby area on land.") }
        static var sampleFallbackTitle: String { L10n.tr("Showing a temporary profile") }
        static var sampleFallbackBody: String { L10n.tr("Live neighborhood data could not be loaded, so Lociq is showing sample metrics for now. Retry to request the selected area again.") }
        static var retry: String { L10n.tr("Retry") }
        static var refreshingScaleBody: String { L10n.tr("Keeping your current profile visible while the selected scale updates.") }
        static var dataZip: String { L10n.tr("Data: ZIP") }
        static var dataTract: String { L10n.tr("Data: Tract") }
        static var dataSample: String { L10n.tr("Data: Sample") }
        static var howToUseTitle: String { L10n.tr("How to use it") }
        static var mapInstructionOne: String { L10n.tr("1. Tap a location on the map.") }
        static var mapInstructionTwo: String { L10n.tr("2. Switch overlay scale at the top.") }
        static var mapInstructionThree: String { L10n.tr("3. Compare how boundaries and context shift between ZIP and tract levels.") }
        static var collapsedHint: String { L10n.tr("Tap on map · swipe up for neighborhood profile") }
        static var profileSubtitle: String { L10n.tr("Real census profile and quick-read insights") }
        static var neighborhoodProfile: String { L10n.tr("Neighborhood profile") }
        static var housingAffordabilityTitle: String { L10n.tr("Housing and affordability") }
        static var homeValue: String { L10n.tr("Home value") }
        static var grossRent: String { L10n.tr("Gross rent") }
        static var workAndHouseholdSnapshot: String { L10n.tr("Work and household snapshot") }
        static var quickSignals: String { L10n.tr("Quick signals") }
        static var remoteWork: String { L10n.tr("Remote work") }
        static var poverty: String { L10n.tr("Poverty") }
        static var demographicCompositionVisual: String { L10n.tr("Demographic composition") }
        static var white: String { L10n.tr("White") }
        static var black: String { L10n.tr("Black") }
        static var asian: String { L10n.tr("Asian") }
        static var hispanicLatino: String { L10n.tr("Hispanic/Latino") }
        static var noGeneratedInsights: String { L10n.tr("No generated insights yet for this location.") }
        static var occupancyMix: String { L10n.tr("Occupancy mix") }
        static var housing: String { L10n.tr("Housing") }
        static var affordability: String { L10n.tr("Affordability") }
        static var mobility: String { L10n.tr("Mobility") }
        static var demographics: String { L10n.tr("Demographics") }
        static var services: String { L10n.tr("Services") }
        static var geography: String { L10n.tr("Geography") }
        static var onboardingTitleOne: String { L10n.tr("Explore neighborhoods fast") }
        static var onboardingBodyOne: String { L10n.tr("Tap any spot on the map to load local Census context in seconds.") }
        static var onboardingTitleTwo: String { L10n.tr("Compare ZIP and Tract") }
        static var onboardingBodyTwo: String { L10n.tr("Switch scales to see how metrics shift between broader and finer boundaries.") }
        static var onboardingTitleThree: String { L10n.tr("Swipe up for deeper context") }
        static var onboardingBodyThree: String { L10n.tr("Expand the bottom sheet to view housing, work, and demographic composition details.") }
        static var onboardingNext: String { L10n.tr("Next") }
        static var onboardingGetStarted: String { L10n.tr("Get Started") }
        static var onboardingSkip: String { L10n.tr("Skip") }
        static var overview: String { L10n.tr("Overview") }
        static var currentScale: String { L10n.tr("Current scale") }
        static var share: String { L10n.tr("Share") }
        static var compareAction: String { L10n.tr("Compare") }
        static var compareModeTitle: String { L10n.tr("Compare places") }
        static var compareZipDetail: String { L10n.tr("Side-by-side ZIP metrics for two selected places.") }
        static var compareTractDetail: String { L10n.tr("Side-by-side tract metrics for two selected places.") }
        static var compareReplace: String { L10n.tr("Change") }
        static var compareDone: String { L10n.tr("Done comparing") }
        static var compareVersus: String { L10n.tr("vs") }
        static var compareLoadingTitle: String { L10n.tr("Loading place") }
        static var compareUnavailableTitle: String { L10n.tr("Could not load comparison") }
        static var compareLoadFailedBody: String { L10n.tr("Lociq could not load metrics for the comparison place right now. Try another place or try again in a moment.") }
        static var compareNoCoverageBody: String { L10n.tr("That place does not map to a ZIP-backed neighborhood profile that Lociq can compare.") }
        static var comparePickerTitle: String { L10n.tr("Choose another place") }
        static var comparePickerBody: String { L10n.tr("Search for a second ZIP, city, neighborhood, or address to compare beside the current profile.") }
        static var tractFallbackTitle: String { L10n.tr("ZIP fallback active") }
        static var tractFallbackBody: String { L10n.tr("Tract data is unavailable for this selection, so the profile is showing ZIP-level Census data.") }
        static var mapTipTitle: String { L10n.tr("Tap to explore") }
        static var mapTipBody: String { L10n.tr("Select any point on the map to load a neighborhood profile, then switch between ZIP and tract.") }
        static var dismiss: String { L10n.tr("Dismiss") }
        static var searchPlaceholder: String { L10n.tr("Search ZIP, city, neighborhood, or address") }
        static var clearSearch: String { L10n.tr("Clear search") }
        static var searchCancel: String { L10n.tr("Cancel") }
        static var searchPromptTitle: String { L10n.tr("Find a place") }
        static var searchPromptBody: String { L10n.tr("Search ZIPs, cities, neighborhoods, and street addresses to jump straight to the area on the map.") }
        static var searchingPlaces: String { L10n.tr("Searching places") }
        static var searchingPlacesBody: String { L10n.tr("Looking up matching ZIPs, cities, neighborhoods, and addresses.") }
        static var noSearchResultsTitle: String { L10n.tr("No places found") }
        static var noSearchResultsBody: String { L10n.tr("Try a different ZIP, city, neighborhood, or street address.") }
        static var searchUnavailableTitle: String { L10n.tr("Search is unavailable") }
        static var searchErrorBody: String { L10n.tr("The app could not load search results right now. Try again in a moment.") }
        static var noZipAvailableNotice: String { L10n.tr("No ZIP code is available for this location. Try a nearby area on land.") }
        static var googleMapsKeyRequired: String { L10n.tr("Google Maps Key Required") }
        static var googleMapsKeyBody: String { L10n.tr("Add GOOGLE_MAPS_API_KEY in Config/GoogleMaps.xcconfig or your scheme environment variables.") }
        static var loadingBoundary: String { L10n.tr("Loading boundary") }
        static var updatingNeighborhoodOutline: String { L10n.tr("Updating neighborhood outline") }
        static var locationUnavailable: String { L10n.tr("Location unavailable") }
        static var appTitle: String { L10n.tr("Lociq") }
        static var ipadSidebarBody: String { L10n.tr("Review the neighborhood profile while the map stays live.") }
        static var profile: String { L10n.tr("Profile") }
        static var guide: String { L10n.tr("Guide") }
        static var tapMapToLoadContext: String { L10n.tr("Tap the map to load ZIP and tract context.") }
        static var tapTheMap: String { L10n.tr("Tap the map") }
        static var expandForMore: String { L10n.tr("Expand for more") }
        static var tapAPlace: String { L10n.tr("Tap a place") }
        static var compareScales: String { L10n.tr("Compare scales") }
        static var readTheProfile: String { L10n.tr("Read the profile") }
        static var usingBroaderZIPContext: String { L10n.tr("Using broader ZIP context") }
        static var broaderNeighborhoodRead: String { L10n.tr("Broader neighborhood read") }
        static var finerLocalContext: String { L10n.tr("Finer local context") }
        static var valuesAreEstimatesShort: String { L10n.tr("Values are estimates") }
        static var latestACSDataset: String { L10n.tr("Latest ACS dataset") }
        static var boundaryGeometry: String { L10n.tr("Boundary geometry") }
        static var refreshBehavior: String { L10n.tr("Refresh behavior") }
        static var censusValuesIncludeStatisticalUncertainty: String { L10n.tr("Census values include statistical uncertainty") }
        static var zipAndTractPolygonsGeneralized: String { L10n.tr("ZIP and tract polygons are generalized for map display") }
        static var profilesUpdateEachTime: String { L10n.tr("Profiles update each time you tap a new location") }
        static var savePlace: String { L10n.tr("Save place") }
        static var removeSavedPlace: String { L10n.tr("Remove saved place") }
        static var removeRecentLookup: String { L10n.tr("Remove recent lookup") }
        static var removeLibraryItem: String { L10n.tr("Remove") }
        static var libraryDetails: String { L10n.tr("Library details") }
        static var customLabel: String { L10n.tr("Custom label") }
        static var notes: String { L10n.tr("Notes") }
        static var pinNeighborhood: String { L10n.tr("Pin neighborhood") }
        static var unpinNeighborhood: String { L10n.tr("Unpin neighborhood") }
        static var pinned: String { L10n.tr("Pinned") }
        static var saveDetails: String { L10n.tr("Save details") }
        static var comparisonShare: String { L10n.tr("Share comparison") }
        static var saveComparison: String { L10n.tr("Save comparison") }
        static var removeSavedComparison: String { L10n.tr("Remove saved comparison") }
        static var savedComparisons: String { L10n.tr("Saved comparisons") }
        static var editLibraryEntry: String { L10n.tr("Edit library entry") }
        static var addNotesOrLabel: String { L10n.tr("Add notes or label") }
    }

    enum Formats {
        static func zip(_ value: String) -> String {
            L10n.format("ZIP %@", fallback: "ZIP %@", value)
        }

        static func tract(_ value: String) -> String {
            L10n.format("Tract %@", fallback: "Tract %@", value)
        }

        static func refreshingScale(_ value: String) -> String {
            L10n.format("Refreshing %@ view", fallback: "Refreshing %@ view", value)
        }

        static func step(_ value: Int) -> String {
            L10n.format("%d", fallback: "%d", value)
        }

        static func compareLoadingInline(_ value: String) -> String {
            L10n.format("Comparing %@ with another place...", fallback: "Comparing %@ with another place...", value)
        }

        static func ownerOccupied(_ owner: String, renter: String) -> String {
            L10n.format("%@ owner-occupied, %@ renter-occupied", fallback: "%@ owner-occupied, %@ renter-occupied", owner, renter)
        }

        static func homeownership(_ ownerPct: String, householdSize: String) -> String {
            L10n.format("Homeownership at %@ with average household size of %@", fallback: "Homeownership at %@ with average household size of %@", ownerPct, householdSize)
        }

        static func housingSnapshotHomeValue(_ value: String, qualifier: String) -> String {
            if qualifier.isEmpty {
                return L10n.format("Median home value: %@", fallback: "Median home value: %@", value)
            }
            return L10n.format("Median home value: %@ %@", fallback: "Median home value: %@ %@", value, qualifier)
        }

        static func housingSnapshotRent(_ value: String, qualifier: String) -> String {
            if qualifier.isEmpty {
                return L10n.format("Median gross rent: %@", fallback: "Median gross rent: %@", value)
            }
            return L10n.format("Median gross rent: %@ %@", fallback: "Median gross rent: %@ %@", value, qualifier)
        }

        static func peoplePerHousehold(_ value: String) -> String {
            L10n.format("%@ people per household.", fallback: "%@ people per household.", value)
        }

        static func workersReportWorkingFromHome(_ value: String) -> String {
            L10n.format("%@ of workers report working from home.", fallback: "%@ of workers report working from home.", value)
        }

        static func belowPovertyLine(_ value: String) -> String {
            L10n.format("%@ of people are below the poverty line (ACS estimate).", fallback: "%@ of people are below the poverty line (ACS estimate).", value)
        }
    }

    enum Insight {
        static var housingSnapshotTitle: String { L10n.tr("Housing snapshot") }
        static var averageHouseholdSizeTitle: String { L10n.tr("Average household size") }
        static var remoteWorkCommonTitle: String { L10n.tr("Remote-work common") }
        static var remoteWorkLessCommonTitle: String { L10n.tr("Remote-work less common") }
        static var higherPovertyRateTitle: String { L10n.tr("Higher poverty rate") }
        static var lowerPovertyRateTitle: String { L10n.tr("Lower poverty rate") }
        static var povertyRateTitle: String { L10n.tr("Poverty rate") }
        static var highQualifier: String { L10n.tr("(high)") }
    }

    enum More {
        static var heroTitle: String { L10n.tr("How Lociq works") }
        static var heroSubtitle: String { L10n.tr("A quick guide to reading the map and profile cards.") }
        static var heroBody: String { L10n.tr("Tap a place, compare ZIP and tract views, and use the sheet to understand the area without digging through raw Census tables.") }
        static var broadScan: String { L10n.tr("Broad scan") }
        static var localDetail: String { L10n.tr("Local detail") }
        static var tapAnySpot: String { L10n.tr("Tap any spot") }
        static var tapAnySpotDetail: String { L10n.tr("Select a location and load a neighborhood profile for that area.") }
        static var switchScale: String { L10n.tr("Switch scale") }
        static var switchScaleDetail: String { L10n.tr("Use ZIP for a broader read and tract for more local variation.") }
        static var readTheProfileDetail: String { L10n.tr("Swipe up to compare population, income, age, housing, and context.") }
        static var startHere: String { L10n.tr("Start here") }
        static var startHereSubtitle: String { L10n.tr("The fastest way to get useful signal from the app") }
        static var zipVsTract: String { L10n.tr("ZIP vs Tract") }
        static var zipVsTractSubtitle: String { L10n.tr("Use each scale for a different kind of question") }
        static var zipTitle: String { L10n.tr("ZIP") }
        static var zipDetail: String { L10n.tr("Best for a broader neighborhood read and faster comparison across larger areas.") }
        static var broaderView: String { L10n.tr("Broader view") }
        static var tractTitle: String { L10n.tr("Tract") }
        static var tractDetail: String { L10n.tr("Best for finer local context when nearby blocks may differ within the same ZIP.") }
        static var closerView: String { L10n.tr("Closer view") }
        static var tip: String { L10n.tr("Tip") }
        static var tipDetail: String { L10n.tr("If two nearby places look similar in ZIP view, switch to tract to check for more local variation.") }
        static var whatYoureSeeing: String { L10n.tr("What you’re seeing") }
        static var whatYoureSeeingSubtitle: String { L10n.tr("How to interpret the profile without reading every number in depth") }
        static var populationMeaning: String { L10n.tr("How many people live in the selected area.") }
        static var medianIncomeMeaning: String { L10n.tr("A quick proxy for household earning power in the area.") }
        static var medianAgeMeaning: String { L10n.tr("Whether the area skews younger, older, or more mixed.") }
        static var householdsMeaning: String { L10n.tr("How many occupied homes are represented in this profile.") }
        static var homeValueRentMeaning: String { L10n.tr("A fast read on local housing cost pressure.") }
        static var occupancyMixMeaning: String { L10n.tr("Owner-occupied versus renter-occupied homes.") }
        static var remoteWorkPovertyMeaning: String { L10n.tr("Two signals that can help describe work patterns and economic strain.") }
        static var demographicCompositionMeaning: String { L10n.tr("Relative group counts shown as simple visual comparisons.") }
        static var mapControls: String { L10n.tr("Map controls") }
        static var mapControlsSubtitle: String { L10n.tr("Quick camera actions while exploring") }
        static var myArea: String { L10n.tr("My Area") }
        static var myAreaDetail: String { L10n.tr("Centers the map on your current location, or your latest selected area if location is unavailable.") }
        static var resetMap: String { L10n.tr("Reset Map") }
        static var resetMapDetail: String { L10n.tr("Returns to the default city overview so you can quickly start a new comparison.") }
        static var privacyTrust: String { L10n.tr("Privacy and data trust") }
        static var privacyTrustSubtitle: String { L10n.tr("What the app uses and what it does not") }
        static var locationOptional: String { L10n.tr("Location is optional") }
        static var locationOptionalDetail: String { L10n.tr("Lociq uses location to center the map and help you explore nearby areas more quickly.") }
        static var noAccountRequired: String { L10n.tr("No account required") }
        static var noAccountRequiredDetail: String { L10n.tr("You can use the app without signing in or creating a personal profile.") }
        static var officialPublicData: String { L10n.tr("Official public data") }
        static var officialPublicDataDetail: String { L10n.tr("Profiles are built from U.S. Census ACS estimates and public geography services.") }
        static var theseAreEstimates: String { L10n.tr("These are estimates") }
        static var theseAreEstimatesDetail: String { L10n.tr("Census values are statistical estimates and should be treated as directional context, not exact counts.") }
        static var usCensusBureau: String { L10n.tr("U.S. Census Bureau") }
        static var acs5YearEstimates: String { L10n.tr("ACS 5-Year Estimates") }
        static var tigerwebGeometry: String { L10n.tr("TIGERweb Geometry") }
        static var fccBlockLookup: String { L10n.tr("FCC Block Lookup") }
        static var primarySources: String { L10n.tr("Primary sources") }
        static var primarySourcesSubtitle: String { L10n.tr("The public datasets behind Lociq") }
        static var dataQualityNotes: String { L10n.tr("Data quality notes") }
        static var dataQualityNotesSubtitle: String { L10n.tr("Useful caveats when comparing places") }
        static var savedPlaces: String { L10n.tr("Saved places") }
        static var savedPlacesSubtitle: String { L10n.tr("Bookmark neighborhoods to reopen them quickly from any device size") }
        static var noSavedPlacesYet: String { L10n.tr("No saved places yet. Open a neighborhood profile and tap the bookmark button to keep it handy.") }
        static var recentLookups: String { L10n.tr("Recent lookups") }
        static var recentLookupsSubtitle: String { L10n.tr("Jump back to neighborhoods you explored recently") }
        static var noRecentLookupsYet: String { L10n.tr("Recent places will appear here after you explore the map.") }
        static var pinnedNeighborhoods: String { L10n.tr("Pinned neighborhoods") }
        static var pinnedNeighborhoodsSubtitle: String { L10n.tr("Keep a short list of places you want to revisit first") }
        static var noPinnedNeighborhoodsYet: String { L10n.tr("Pin a saved place to keep it at the top of your library.") }
        static var savedComparisonsSubtitle: String { L10n.tr("Reopen side-by-side place comparisons without searching again") }
        static var noSavedComparisonsYet: String { L10n.tr("Save an active comparison from the profile sheet to keep it in your library.") }
        static var notesPlaceholder: String { L10n.tr("Capture why this place matters, what stood out, or what you want to revisit later.") }
        static var labelPlaceholder: String { L10n.tr("Optional short label") }
        static var comparisonLibraryHint: String { L10n.tr("Tap a saved comparison to reopen it in the map view.") }
    }

    enum Network {
        static let fccCensusURL = "https://geo.fcc.gov/api/census/block/find"
        static let jsonFormat = "json"
        static let defaultSeed = "default"
    }

    enum QueryItems {
        static let responseFormat = "format"
        static let latitude = "latitude"
        static let longitude = "longitude"
    }

    enum Debug {
        static let acsZipFailed = "ACS ZCTA fetch failed:"
    }

    enum Release {
        static var latestACS5YearDataset: String { L10n.tr("2022 ACS 5-Year release") }
    }
}

enum SampleData {
    static let years = ["2019", "2020", "2021", "2022", "2023", "2024"]
    static let ageLabels = ["0–14", "15–24", "25–34", "35–44", "45–64", "65+"]
    static let educationLabels = ["HS", "Some College", "Bachelor's", "Graduate"]
    static let incomeLabels = ["<50k", "50–100k", "100–150k", "150–200k", ">200k"]
}

enum IconNames {
    static let map = "map"
    static let mapFilled = "map.fill"
    static let more = "ellipsis.circle"
    static let moreFilled = "ellipsis.circle.fill"
    static let person = "person.3"
    static let personFilled = "person.3.fill"
    static let money = "dollarsign.circle"
    static let clock = "clock"
    static let house = "house"
    static let chevronUp = "chevron.up"
    static let houseFilled = "house.fill"
    static let keyFilled = "key.fill"
    static let affordabilityFilled = "dollarsign.circle.fill"
    static let mobilityFilled = "car.fill"
    static let servicesFilled = "building.columns.fill"
    static let demographicsFilled = "person.3.fill"
}

enum NumberFormatting {
    static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        return formatter
    }()

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.locale = .current
        return formatter
    }()

    static func decimalString(_ value: Int) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func currencyString(_ value: Int) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
