import Foundation

enum L10n {
    static func tr(_ key: String, fallback: String? = nil) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback ?? key, table: nil)
    }

    static func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
