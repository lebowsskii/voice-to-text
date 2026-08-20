import Testing
import Foundation
@testable import VoiceToText

@Suite("SettingsState")
struct SettingsStateTests {

    /// A throwaway UserDefaults suite and a throwaway Keychain service per
    /// test, so tests never see each other's state and never touch the
    /// user's real defaults or real stored API key.
    private func freshState() -> SettingsState {
        let suiteName = "SettingsStateTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        let apiKeyStore = GeminiAPIKeyStore(service: suiteName)
        return SettingsState(store: store, apiKeyStore: apiKeyStore, loginItemStore: LoginItemStore())
    }

    private func freshState(sharing store: SettingsStore, service: String) -> SettingsState {
        SettingsState(store: store, apiKeyStore: GeminiAPIKeyStore(service: service), loginItemStore: LoginItemStore())
    }

    @Test("defaults to Parakeet when nothing was ever saved")
    func defaultsToParakeet() {
        #expect(freshState().selectedEngine == .parakeet)
    }

    @Test("changing selectedEngine persists through a new SettingsState reading the same store")
    func persistsAcrossInstances() {
        let suiteName = "SettingsStateTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)

        let first = freshState(sharing: store, service: suiteName)
        first.selectedEngine = .whisper

        let second = freshState(sharing: store, service: suiteName)
        #expect(second.selectedEngine == .whisper)
    }

    @Test("Gemini thinking is disabled by default")
    func geminiThinkingDisabledByDefault() {
        #expect(freshState().geminiDisableThinking == true)
    }

    @Test("changing geminiSelectedModel and geminiDisableThinking persists through a new SettingsState reading the same store")
    func geminiFieldsPersistAcrossInstances() {
        let suiteName = "SettingsStateTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)

        let first = freshState(sharing: store, service: suiteName)
        first.geminiSelectedModel = "gemini-3.1-flash-lite"
        first.geminiDisableThinking = false

        let second = freshState(sharing: store, service: suiteName)
        #expect(second.geminiSelectedModel == "gemini-3.1-flash-lite")
        #expect(second.geminiDisableThinking == false)
    }

    @Test("geminiAPIKey round-trips through the Keychain and reports empty when never set")
    func geminiAPIKeyRoundTrips() {
        let state = freshState()
        #expect(state.geminiAPIKey == "")

        state.geminiAPIKey = "test-key-123"
        #expect(state.geminiAPIKey == "test-key-123")

        state.geminiAPIKey = ""
        #expect(state.geminiAPIKey == "")
    }

    @Test("selectedMicDeviceUID defaults to nil (system default) when nothing was ever saved")
    func selectedMicDeviceUIDDefaultsToNil() {
        #expect(freshState().selectedMicDeviceUID == nil)
    }

    @Test("changing selectedMicDeviceUID persists through a new SettingsState reading the same store, including back to nil")
    func selectedMicDeviceUIDPersistsAcrossInstances() {
        let suiteName = "SettingsStateTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)

        let first = freshState(sharing: store, service: suiteName)
        first.selectedMicDeviceUID = "AppleUSBAudioEngine:Some Vendor:USB Mic:12345"

        let second = freshState(sharing: store, service: suiteName)
        #expect(second.selectedMicDeviceUID == "AppleUSBAudioEngine:Some Vendor:USB Mic:12345")

        second.selectedMicDeviceUID = nil
        let third = freshState(sharing: store, service: suiteName)
        #expect(third.selectedMicDeviceUID == nil)
    }

    /// `hasGeminiAPIKey` is the observable stand-in the Settings UI watches —
    /// it has to track every write to the computed, unobservable key.
    @Test("hasGeminiAPIKey tracks the stored key through set, clear, and a fresh instance")
    func hasGeminiAPIKeyTracksTheKey() {
        let suiteName = "SettingsStateTests.\(UUID().uuidString)"
        let store = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)

        let state = freshState(sharing: store, service: suiteName)
        #expect(state.hasGeminiAPIKey == false)

        state.geminiAPIKey = "test-key-123"
        #expect(state.hasGeminiAPIKey == true)
        #expect(freshState(sharing: store, service: suiteName).hasGeminiAPIKey == true)

        state.geminiAPIKey = ""
        #expect(state.hasGeminiAPIKey == false)
        #expect(freshState(sharing: store, service: suiteName).hasGeminiAPIKey == false)
    }
}
