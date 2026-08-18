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

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        self.selectedEngine = store.selectedEngine
    }
}
