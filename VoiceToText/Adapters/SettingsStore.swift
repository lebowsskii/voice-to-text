import Foundation

/// Persists user-facing settings across launches. The only place
/// `UserDefaults` is touched — the Gemini API key is the one exception,
/// stored in the Keychain by `GeminiAPIKeyStore` instead.
final class SettingsStore {
    private let defaults: UserDefaults
    private let selectedEngineKey = "selectedEngine"
    private let geminiSelectedModelKey = "geminiSelectedModel"
    private let geminiDisableThinkingKey = "geminiDisableThinking"

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

    var geminiSelectedModel: String {
        get { defaults.string(forKey: geminiSelectedModelKey) ?? "" }
        set { defaults.set(newValue, forKey: geminiSelectedModelKey) }
    }

    /// Whether `thinkingConfig` is sent to suppress Gemini's reasoning step.
    /// Defaults to on: thinking adds latency with no benefit for a plain
    /// transcription request.
    var geminiDisableThinking: Bool {
        get { defaults.object(forKey: geminiDisableThinkingKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: geminiDisableThinkingKey) }
    }
}
