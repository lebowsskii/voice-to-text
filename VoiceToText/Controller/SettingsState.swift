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

    /// `nil` means "use the system default input device".
    var selectedMicDeviceUID: String? {
        didSet {
            guard selectedMicDeviceUID != oldValue else { return }
            store.selectedMicDeviceUID = selectedMicDeviceUID
        }
    }

    /// A display string for the current toggle-dictation hotkey, e.g. "⌥⌘Z".
    /// `KeyboardShortcuts` owns the actual binding and its own storage — this
    /// is only a mirror the UI can observe. `@Observable` can't see straight
    /// through to `KeyboardShortcuts.getShortcut(for:)`, since nothing about
    /// that call is tracked, so without a stored property like this one the
    /// menu bar label would keep showing whatever combo was current the last
    /// time its view happened to re-render for an unrelated reason — not
    /// necessarily the one actually bound right now. Not persisted through
    /// `store`: `KeyboardShortcuts` already persists the real binding.
    var toggleDictationShortcutDescription = "Not set"

    /// Whether a key is stored, as a *stored* property so `@Observable` can
    /// actually instrument it. `geminiAPIKey` below is computed, and
    /// `@Observable` only tracks stored properties — a view reading it
    /// registers no dependency and a write emits no change notification, so
    /// the Settings UI would never redraw on its own after a save. Views that
    /// only need to know whether a key exists read this instead; the secret
    /// itself still lives nowhere but the Keychain.
    private(set) var hasGeminiAPIKey: Bool

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
            hasGeminiAPIKey = !newValue.isEmpty
        }
    }

    /// A *stored* property, read once from `SMAppService` at launch and
    /// updated optimistically on toggle — not recomputed from
    /// `loginItemStore.isEnabled` on every read. `SMAppService.mainApp.status`
    /// is known to intermittently misreport `.notFound` for an already-registered
    /// app (observed on ad-hoc-signed debug builds run from DerivedData rather
    /// than a stable `/Applications` install); re-deriving this property from a
    /// live query on every view redraw let that transient misreport snap the
    /// toggle back off seconds after the user turned it on, even though the
    /// login item was never actually removed.
    var launchAtLogin: Bool {
        didSet {
            // `isRevertingLaunchAtLogin` guards against re-entering this
            // `didSet` when the catch block below reassigns `launchAtLogin`
            // back to `oldValue` — without it, that reassignment would
            // trigger `didSet` again and fire a second, unwanted
            // `setEnabled` call.
            guard !isRevertingLaunchAtLogin, launchAtLogin != oldValue else { return }
            do {
                try loginItemStore.setEnabled(launchAtLogin)
            } catch {
                isRevertingLaunchAtLogin = true
                launchAtLogin = oldValue
                isRevertingLaunchAtLogin = false
            }
        }
    }
    private var isRevertingLaunchAtLogin = false

    private let store: SettingsStore
    private let apiKeyStore: GeminiAPIKeyStore
    private let loginItemStore: LoginItemStore

    init(store: SettingsStore, apiKeyStore: GeminiAPIKeyStore, loginItemStore: LoginItemStore) {
        self.store = store
        self.apiKeyStore = apiKeyStore
        self.loginItemStore = loginItemStore
        self.selectedEngine = store.selectedEngine
        self.geminiSelectedModel = store.geminiSelectedModel
        self.geminiDisableThinking = store.geminiDisableThinking
        self.selectedMicDeviceUID = store.selectedMicDeviceUID
        self.hasGeminiAPIKey = !(apiKeyStore.get() ?? "").isEmpty
        self.launchAtLogin = loginItemStore.isEnabled
    }
}
