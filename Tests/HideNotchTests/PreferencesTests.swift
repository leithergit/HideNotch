import Foundation
import Testing
@testable import HideNotchCore

struct PreferencesTests {
    let suite = "HideNotchTests.\(UUID().uuidString)"

    func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func overlayEnabledDefaultsToTrue() {
        #expect(Preferences(defaults: makeDefaults()).overlayEnabled)
    }

    @Test func overlayEnabledPersists() {
        let defaults = makeDefaults()
        Preferences(defaults: defaults).overlayEnabled = false
        #expect(!Preferences(defaults: defaults).overlayEnabled)
        defaults.removePersistentDomain(forName: suite)
    }
}
