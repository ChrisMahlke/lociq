import SwiftUI

enum TabSelection {
    case map, library, guide
}

enum BoundaryOverlayScale: String, CaseIterable, Identifiable {
    case zip = "ZIP"
    case tract = "Tract"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .zip:
            return AppStrings.More.zipTitle
        case .tract:
            return AppStrings.More.tractTitle
        }
    }

    var themeColor: Color {
        switch self {
        case .zip: return .blue
        case .tract: return .teal
        }
    }
}
