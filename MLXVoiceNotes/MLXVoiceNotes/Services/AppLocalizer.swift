import Foundation

/// Lightweight localization helper for service layer.
///
/// SwiftUI's `environment(\.locale)` only affects views, not service objects.
/// `String(localized:)` uses the process locale, which may not match the
/// in-app language setting stored in `UserDefaults.appLanguage`.
///
/// `AppLocalizer` resolves the correct `.lproj` bundle based on the
/// persisted `appLanguage` preference, then looks up strings from that bundle.
enum AppLocalizer {
    /// The locale identifier derived from the persisted `appLanguage` setting.
    /// Returns `nil` for `.system` (let Foundation use the process locale).
    private static var preferredLocaleID: String? {
        guard let raw = UserDefaults.standard.string(forKey: "appLanguage"),
              let lang = AppLanguage(rawValue: raw),
              lang != .system else {
            return nil
        }
        return lang.locale?.identifier
    }

    /// The `.lproj` bundle that matches the in-app language preference.
    /// Falls back to the main bundle (process locale) if not found.
    private static var localizationBundle: Bundle {
        guard let id = preferredLocaleID else { return .main }
        // Search for the matching .lproj directory in the main bundle
        if let path = Bundle.main.path(forResource: id, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // Fallback: try base (English)
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    /// Look up a localized string using the in-app language preference.
    /// - Parameters:
    ///   - key: The localization key (same keys used in Localizable.xcstrings)
    ///   - defaultValue: Optional fallback if key is not found
    /// - Returns: The localized string
    static func string(_ key: String, defaultValue: String? = nil) -> String {
        let value = localizationBundle.localizedString(forKey: key, value: nil, table: nil)
        // NSLocalizedString returns the key itself when not found
        if value == key, let fallback = defaultValue {
            return fallback
        }
        return value
    }

    /// Look up a localized string with format arguments.
    /// - Parameters:
    ///   - key: The localization key
    ///   - args: Format arguments (same as `String(format:)`)
    /// - Returns: The formatted localized string
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), arguments: args)
    }
}
