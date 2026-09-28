import Foundation

/// User-facing strings, localized via Resources/<lang>.lproj/Localizable.strings.
public enum L10n {
    static let supportedLanguages = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es", "it", "pt", "th", "vi", "id"]
    static let keys = [
        "menu.hideNotch", "menu.launchAtLogin", "menu.launchAtLogin.failed",
        "menu.launchAtLogin.needsApproval", "menu.quit",
        "alert.enable.title", "alert.enable.message", "alert.enable.confirm", "alert.enable.cancel",
    ]

    static var hideNotch: String { tr("menu.hideNotch") }
    static var launchAtLogin: String { tr("menu.launchAtLogin") }
    static var launchAtLoginFailed: String { tr("menu.launchAtLogin.failed") }
    static var launchAtLoginNeedsApproval: String { tr("menu.launchAtLogin.needsApproval") }
    static var quit: String { tr("menu.quit") }
    static var enableAlertTitle: String { tr("alert.enable.title") }
    static var enableAlertMessage: String { tr("alert.enable.message") }
    static var enableAlertConfirm: String { tr("alert.enable.confirm") }
    static var enableAlertCancel: String { tr("alert.enable.cancel") }

    static func tr(_ key: String, bundle: Bundle = .module) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
