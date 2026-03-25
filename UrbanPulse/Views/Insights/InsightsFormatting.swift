import Foundation

enum InsightsFormatting {
    static func number(_ value: Int?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        return NumberFormatting.decimalString(value)
    }

    static func currency(_ value: Int?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        return "\(AppStrings.Symbols.dollarsPrefix)\(NumberFormatting.decimalString(value))"
    }

    static func percent(_ value: Double?, suffixCount: Int?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        let base = String(format: AppStrings.Symbols.oneDecimalPercentFormat, value)
        if let suffixCount {
            return "\(base) (\(NumberFormatting.decimalString(suffixCount)))"
        }
        return base
    }

    static func normalizedPercent(_ value: Double?) -> Double {
        guard let value else { return 0 }
        return max(0, min(1, value / 100))
    }

    static func demographicShare(_ value: Int?, totalPopulation: Int?) -> Double {
        guard let value, let totalPopulation, totalPopulation > 0 else {
            return 0
        }
        return max(0, min(1, Double(value) / Double(totalPopulation)))
    }

    static func dataSourceText(_ source: MetricsSource) -> String {
        switch source {
        case .zcta: return AppStrings.Labels.dataZip
        case .tract: return AppStrings.Labels.dataTract
        case .sample: return AppStrings.Labels.dataSample
        }
    }
}
