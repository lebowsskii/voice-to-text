import Testing
import Foundation
@testable import VoiceToText

@Suite("SettingsState")
struct SettingsStateTests {

    /// A throwaway UserDefaults suite per test so tests never see each
    /// other's state and never touch the user's real defaults.
    private func freshStore() -> SettingsStore {
        let suiteName = "SettingsStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsStore(defaults: defaults)
    }

    @Test("defaults to Parakeet when nothing was ever saved")
    func defaultsToParakeet() {
        let state = SettingsState(store: freshStore())
        #expect(state.selectedEngine == .parakeet)
    }

    @Test("changing selectedEngine persists through a new SettingsState reading the same store")
    func persistsAcrossInstances() {
        let store = freshStore()
        let first = SettingsState(store: store)
        first.selectedEngine = .whisper

        let second = SettingsState(store: store)
        #expect(second.selectedEngine == .whisper)
    }
}
