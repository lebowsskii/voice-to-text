import Foundation

/// Persists user-facing settings across launches. The only place
/// `UserDefaults` is touched.
final class SettingsStore {
    private let defaults: UserDefaults
    private let selectedEngineKey = "selectedEngine"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedEngine: Engine {
        get {
            defaults.string(forKey: selectedEngineKey)
                .flatMap(Engine.init(rawValue:)) ?? .parakeet
        }
        set { defaults.set(newValue.rawValue, forKey: selectedEngineKey) }
    }
}
