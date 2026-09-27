import Foundation

public final class Preferences {
    static let overlayEnabledKey = "overlayEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.overlayEnabledKey: true])
    }

    public var overlayEnabled: Bool {
        get { defaults.bool(forKey: Self.overlayEnabledKey) }
        set { defaults.set(newValue, forKey: Self.overlayEnabledKey) }
    }
}
