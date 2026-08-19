import Foundation
import Observation

/// The second observable object in the app (alongside `DictationController`):
/// everything the user configures in the Settings window. Dependencies are
/// passed to the initializer, same discipline as `DictationController`.
@Observable
final class SettingsState {
    var selectedEngine: Engine {
        didSet {
            guard selectedEngine != oldValue else { return }
            store.selectedEngine = selectedEngine
        }
    }

    var geminiSelectedModel: String {
        didSet {
            guard geminiSelectedModel != oldValue else { return }
            store.geminiSelectedModel = geminiSelectedModel
        }
    }

    var geminiDisableThinking: Bool {
        didSet {
            guard geminiDisableThinking != oldValue else { return }
            store.geminiDisableThinking = geminiDisableThinking
        }
    }

    /// Not cached in memory — read and written straight through to the
    /// Keychain on every access. Settings opens rarely, and a secret has no
    /// business lingering in a property longer than it has to.
    var geminiAPIKey: String {
        get { apiKeyStore.get() ?? "" }
        set {
            if newValue.isEmpty {
                apiKeyStore.clear()
            } else {
                apiKeyStore.set(newValue)
            }
        }
    }

    private let store: SettingsStore
    private let apiKeyStore: GeminiAPIKeyStore

    init(store: SettingsStore, apiKeyStore: GeminiAPIKeyStore) {
        self.store = store
        self.apiKeyStore = apiKeyStore
        self.selectedEngine = store.selectedEngine
        self.geminiSelectedModel = store.geminiSelectedModel
        self.geminiDisableThinking = store.geminiDisableThinking
    }
}
