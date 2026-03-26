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
        static let dollarsPrefix = "$"
    }

    enum Tabs {
        static let map = "Map"
        static let more = "More"
    }

    enum Metrics {
        static let population = "Population"
        static let medianIncome = "Median Income"
        static let medianAge = "Median Age"
        static let households = "Households"
    }

    enum Labels {
        static let swipeUpForMoreData = "Swipe up for more data"
        static let insights = "Insights"
        static let selectedArea = "Selected area"
        static let noSelectionTitle = "Start with the map"
        static let noSelectionBody = "Tap anywhere to load a neighborhood profile, compare ZIP and tract views, and read the area at a glance."
        static let loadingSelectionTitle = "Loading area profile"
        static let loadingSelectionBody = "Fetching boundaries, Census context, and quick-read signals for your selected location."
        static let dataZip = "Data: ZIP"
        static let dataTract = "Data: Tract"
        static let dataSample = "Data: Sample"
        static let howToUseTitle = "How to use it"
        static let mapInstructionOne = "1. Tap a location on the map."
        static let mapInstructionTwo = "2. Switch overlay scale at the top."
        static let mapInstructionThree = "3. Compare how boundaries and context shift between ZIP and tract levels."
        static let collapsedHint = "Tap on map · swipe up for neighborhood profile"
        static let profileSubtitle = "Real census profile and quick-read insights"
        static let neighborhoodProfile = "Neighborhood profile"
        static let housingAffordabilityTitle = "Housing and affordability"
        static let homeValue = "Home value"
        static let grossRent = "Gross rent"
        static let workAndHouseholdSnapshot = "Work and household snapshot"
        static let quickSignals = "Quick signals"
        static let remoteWork = "Remote work"
        static let poverty = "Poverty"
        static let demographicCompositionVisual = "Demographic composition"
        static let white = "White"
        static let black = "Black"
        static let asian = "Asian"
        static let hispanicLatino = "Hispanic/Latino"
        static let noGeneratedInsights = "No generated insights yet for this location."
        static let occupancyMix = "Occupancy mix"
        static let housing = "Housing"
        static let affordability = "Affordability"
        static let mobility = "Mobility"
        static let demographics = "Demographics"
        static let services = "Services"
        static let geography = "Geography"
        static let onboardingTitleOne = "Explore neighborhoods fast"
        static let onboardingBodyOne = "Tap any spot on the map to load local Census context in seconds."
        static let onboardingTitleTwo = "Compare ZIP and Tract"
        static let onboardingBodyTwo = "Switch scales to see how metrics shift between broader and finer boundaries."
        static let onboardingTitleThree = "Swipe up for deeper context"
        static let onboardingBodyThree = "Expand the bottom sheet to view housing, work, and demographic composition details."
        static let onboardingNext = "Next"
        static let onboardingGetStarted = "Get Started"
        static let onboardingSkip = "Skip"
        static let overview = "Overview"
        static let currentScale = "Current scale"
        static let mapControlsLocate = "Locate"
        static let mapControlsReset = "Reset"
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
        static let latestACS5YearDataset = "2022 ACS 5-Year release"
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
        return formatter
    }()

    static func decimalString(_ value: Int) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
